;;; -*- Mode: CLtL -*-

;;; load-defsystem.lisp --
;;; We cannot have a DEFSYSTEM form for the DEFSYSTEM package in the
;;; first place, due to an obvious "chicken and egg" problem.  So here
;;; is a very old style 'load-' file.

(in-package "COMMON-LISP-USER")

;;;===========================================================================
;;; User definable parameters.

;;; *mk-defsystem-absolute-directory-pathname* --
;;; The location (i.e. a directory) of the MK:DEFSYSTEM distribution.
;;; Please note that the result of PARSE-NAMESTRING must yield a
;;; PATHNAME with PATHNAME-NAME equal to NIL and PATHNAME-DIRECTORY
;;; equal to a list with FIRST equal to :ABSOLUTE and without :WILD or
;;; :WILD-INFERIORS components.

;;; Thanks to Kevin Rosenberg for the following very nice idea.

(defun pathname-host-device-directory (path)
  (check-type path pathname)
  (make-pathname :host (pathname-host path)
                 :device (pathname-device path)
                 :directory (pathname-directory path)
		 :name nil
		 :type nil
		 ))

(defparameter *mk-defsystem-absolute-directory-pathname*
  (pathname-host-device-directory *load-pathname*))

#| Old stuff
#+:CMU
(defparameter *mk-defsystem-absolute-directory-pathname*
  (parse-namestring
   "home:lang/cl/defsystem/make/"))

#+(and windows (or lispworks allegro))
(defparameter *mk-defsystem-absolute-directory-pathname*
  (parse-namestring
   "H:/lang/cl/defsystem/make/"))

#+(and unix (or lispworks allegro))
(defparameter *mk-defsystem-absolute-directory-pathname*
  (parse-namestring
   "/home/marcoxa/lang/cl/defsystem/make/"))
|#

;;; The following three parameters are tested IN SEQUENCE and
;;; exclusively.  The first one found true one will cause the
;;; associated action to be performed.

(defparameter *mk-defsystem-load-source-only-p* t
  "If T, loads only the MK:DEFSYSTEM source files.")

(defparameter *mk-defsystem-load-newer-p* nil
  "If T, loads the MK:DEFSYSTEM source or compiled files, whichever is newer.")

(defparameter *mk-defsystem-compile-and-load-p* t
  "If T, compiles and loads the MK:DEFSYSTEM files.")


;;;===========================================================================
;;; Support code and actual load forms.
;;; You should not be required to look at anyhting beyond this point
;;; if not for debugging purposes.


;;; *mk-defsystem-lp-filenames* --
;;; NOTE: Order is important!!!
;;; The "MAKE-DEFSYSTEM" logical pathname is defined later on.

(defparameter *mk-defsystem-lp-filenames*
  '(
    "MAKE-DEFSYSTEM:adjoin-dirs"
    
    "MAKE-DEFSYSTEM:defsystem-pkg"
    ;; "MAKE-DEFSYSTEM:conditions"
    "MAKE-DEFSYSTEM:utilities;ambler;ambler-pkg"
    "MAKE-DEFSYSTEM:utilities;ambler;ambler"
    ;; "MAKE-DEFSYSTEM:directory-processing"
    "MAKE-DEFSYSTEM:utilities;user-interaction"
    "MAKE-DEFSYSTEM:utilities;y-or-n-p-wait"
    "MAKE-DEFSYSTEM:utilities;run-os-program"
    "MAKE-DEFSYSTEM:utilities;save-image"

    "MAKE-DEFSYSTEM:language-support"
    "MAKE-DEFSYSTEM:languages;c;c"
    "MAKE-DEFSYSTEM:languages;fortran;fortran"
    ;; "MAKE-DEFSYSTEM:languages;ada;ada"
    ;; "MAKE-DEFSYSTEM:languages;scheme;scheme"

    "MAKE-DEFSYSTEM:versions"
    "MAKE-DEFSYSTEM:base-components"
    "MAKE-DEFSYSTEM:predefined-components"
    "MAKE-DEFSYSTEM:predefined-specialized-components"

    "MAKE-DEFSYSTEM:impl-dependent;common"
    #+cmu "MAKE-DEFSYSTEM:impl-dependent;cmucl"
    #+clisp "MAKE-DEFSYSTEM:impl-dependent;clisp"
    #+lispworks "MAKE-DEFSYSTEM:impl-dependent;lispworks"
    #+allegro "MAKE-DEFSYSTEM:impl-dependent;allegro"
    #+mcl "MAKE-DEFSYSTEM:impl-dependent;mcl"
    #+genera "MAKE-DEFSYSTEM:impl-dependent;genera"
    #+lcl "MAKE-DEFSYSTEM:impl-dependent;lcl"
    #+cormanlisp "MAKE-DEFSYSTEM:impl-dependent;corman"
    #+poplog "MAKE-DEFSYSTEM:impl-dependent;poplog"
    #+(or kcl ibcl akcl ecl gcl) "MAKE-DEFSYSTEM:impl-dependent;kcl-derivates"

    "MAKE-DEFSYSTEM:defsystem"
    "MAKE-DEFSYSTEM:defsystem-protocol"
    "MAKE-DEFSYSTEM:actions"
    ;; "MAKE-DEFSYSTEM:provide-require"

    "MAKE-DEFSYSTEM:syntax"
    ))

(defparameter *mk-defsystem-load-debug-only-p* nil)

;;; The main load/compile/configure code.

(eval-when (:load-toplevel :execute)

  ;; Setting up a useful logical pathnames.
  ;; To be sure, each subdirectory is treated separatedly, to avoid
  ;; problems with implementations which cannot handle '**' as
  ;; :WILD-INFERIORS on the right hand side of the definitions.
  ;; For the time being, since we only have three subdirectories it
  ;; should not be a problem.
  
  (setf (logical-pathname-translations "MAKE-DEFSYSTEM")
	`(("impl-dependent;*.*.*"
	   ,(make-pathname
	     :host (pathname-host *mk-defsystem-absolute-directory-pathname*)
	     :device (pathname-device *mk-defsystem-absolute-directory-pathname*)
	     :directory (append (pathname-directory
				 *mk-defsystem-absolute-directory-pathname*)
				'("impl-dependent"))))
	  #|("utilities;*.*.*"
	   ,(make-pathname
	     :host (pathname-host *mk-defsystem-absolute-directory-pathname*)
	     :device (pathname-device *mk-defsystem-absolute-directory-pathname*)
	     :directory (append (pathname-directory
				 *mk-defsystem-absolute-directory-pathname*)
				'("utilities"))))|#
	  ("utilities;**;*.*.*"
	   ,(make-pathname
	     :host (pathname-host *mk-defsystem-absolute-directory-pathname*)
	     :device (pathname-device *mk-defsystem-absolute-directory-pathname*)
	     :directory (append (pathname-directory
				 *mk-defsystem-absolute-directory-pathname*)
				'("utilities" :wild-inferiors))))
	  ("languages;**;*.*.*"
	   ,(make-pathname
	     :host (pathname-host *mk-defsystem-absolute-directory-pathname*)
	     :device (pathname-device *mk-defsystem-absolute-directory-pathname*)
	     :directory (append (pathname-directory
				 *mk-defsystem-absolute-directory-pathname*)
				'("languages" :wild-inferiors))))
	  ("cl-environment;*.*.*"
	   ,(make-pathname
	     :host (pathname-host *mk-defsystem-absolute-directory-pathname*)
	     :device (pathname-device *mk-defsystem-absolute-directory-pathname*)
	     :directory (append (pathname-directory
				 *mk-defsystem-absolute-directory-pathname*)
				'("cl-environment")))
	   )
	  ("*.*.*" ,*mk-defsystem-absolute-directory-pathname*)
	  ("*.*" ,*mk-defsystem-absolute-directory-pathname*)
	  ))

  (flet ((load-compiling-if-needed (lp-string-filename-sans-extension)
	   (declare (type string lp-string-filename-sans-extension))
	   (let* ((compiled-file-type
		   (pathname-type
		    (compile-file-pathname *default-pathname-defaults*)))

		  (lp-string-binary-filename
		   (concatenate 'string
				lp-string-filename-sans-extension
				"."
				compiled-file-type))

		  (lp-string-source-filename
		   (concatenate 'string
				lp-string-filename-sans-extension
				".lisp"))

		  (binary-physical-filename
		   (translate-logical-pathname lp-string-binary-filename))

		  (source-physical-filename
		   (translate-logical-pathname lp-string-source-filename))
		  )
	     (cond (*mk-defsystem-load-debug-only-p*
		    (format t "MK:DEFSYSTEM loading:~@
                               - ~S~%- ~S~%- ~S~%- ~S~%- ~S~%"
			    lp-string-filename-sans-extension
			    lp-string-source-filename
			    lp-string-binary-filename
			    source-physical-filename
			    binary-physical-filename
			    ))
		   (*mk-defsystem-load-source-only-p*
		    (load source-physical-filename :print nil))

		   (*mk-defsystem-load-newer-p*
		    (if (and (probe-file binary-physical-filename)
			     (> (file-write-date binary-physical-filename)
				(file-write-date source-physical-filename)))
			(load binary-physical-filename :print nil)
			(load source-physical-filename :print nil)))

		   (*mk-defsystem-compile-and-load-p*
		    (cond ((and (probe-file binary-physical-filename)
				(> (file-write-date binary-physical-filename)
				   (file-write-date source-physical-filename)))
			   (load binary-physical-filename :print nil))
			  (t
			   (compile-file source-physical-filename
					 :output-file binary-physical-filename
					 :print nil)
			   (load binary-physical-filename :print nil))))
		   )))			; end of load-compiling-if-needed
	 )
    (format *trace-output*
	    "~&;;; MAKE: Loading MK:DEFSYSTEM package version ~A." "4.0")
    (unless (member :cl-environment *features*)
      (format *trace-output*
	      "~&;;; MAKE: Ensuring CL-ENVIRONMENT package is present.")
      (unless (probe-file "MAKE-DEFSYSTEM:cl-environment;load-cl-environment.lisp")
	(error "Cannot find CL-ENVIRONMENT loader file ~@
                MAKE-DEFSYSTEM:cl-environment;load-cl-environment.lisp.~@
                Please make sure that CL-ENVIRONEMT is loaded in your ~
                system.~@
                You can find CL-ENVIRONMENT in the CLOCC at~@
                <http://sourceforge.net/projects/clocc>."))
      (load "MAKE-DEFSYSTEM:cl-environment;load-cl-environment.lisp"
	    :verbose nil
	    :print nil)
      (load-cl-environment-library
       :directory (translate-logical-pathname "MAKE-DEFSYSTEM:cl-environment;")
       :load-verbose nil))
    (let ((*load-verbose* t))
      (dolist (f *mk-defsystem-lp-filenames*)
	(load-compiling-if-needed f)))
    ))


;;; end of file -- load-defsystem.lisp --
;-*- Mode: Common-lisp; Package: ytools; Readtable: ytools; -*-
(in-package :ytools)
;;;$Id: slurp.lisp,v 1.8.2.14 2005/02/05 02:38:26 airfoyle Exp $

;;; Copyright (C) 1976-2004
;;;     Drew McDermott and Yale University.  All rights reserved.
;;; This software is released under the terms of the Modified BSD
;;; License.  See file COPYING for details.

(eval-when (:load-toplevel)
   (export '(in-readtable in-regime needed-by-macros
	     with-post-file-transduction-hooks after-file-transduction
	     during-file-transduction setf-during-file-transduction 
	     fload-verbose* eval-when-slurping
	     make-Printable printable-as-string eof*)))

(defvar source-suffixes* (adjoin lisp-source-extn* '("lisp") :test #'equal))
(defvar obj-suffix* lisp-object-extn*)
(defvar object-suffixes* `(,lisp-object-extn*))

(defun pathname-is-source (pn)
   (member (Pathname-type pn)
	   source-suffixes*
	   :test #'string=))

(defun pathname-is-object (pn)
   (member (Pathname-type pn)
	   object-suffixes*))

(eval-when (:compile-toplevel :load-toplevel)

;;; Useful for constructing "marker" objects that have nothing but their
;;; identity: none of them is EQ to anything encountered in an ordinary
;;; S-expression.
(defstruct (Printable (:print-function
		         (lambda (me str d)
			         (declare (ignore d))
			    (funcall (Printable-printer me) str)))
	              (:constructor make-Printable (printer)))
   printer
   (sym nil))

(defun printable-as-string (s)
   ;; We resort to these strange devices so that this sort of
   ;; Printable is uniquified, but only relative to the current
   ;; package --
   (let ((sym (intern s)))
      (let ((p (make-Printable (\\ (srm) (format srm "~a" s)))))
	 (setf (Printable-sym p) sym)
	 (setf (get sym 'printable) p)
	 p)))

(defmethod make-load-form ((p Printable) &optional env)
                          (declare (ignore env))
   (let ((sym (Printable-sym p)))
      (cond ((and sym (get sym 'printable))
	     `(or (get ',sym 'printable)
		  (printable-as-string ',(symbol-name sym))))
	    (t
	     `(make-Printable ',(Printable-printer p))))))
)

(defvar eof* (printable-as-string "#<End of file>"))
;;;;(make-Printable (\\ (srm) (format srm "~a" "#<End of file>")))

(defstruct (Slurp-task
;;;;	      (:constructor make-Slurp-task (label default-handler))
           )
   label
   (handler-table (make-hash-table :test #'eq :size 100))
   default-handler
   file->state-fcn) 
;;; -- handler-table maps symbols to functions of one argument that
;;; handle forms beginning with that symbol
;;; default-handler is for all other forms.  If it's false, then
;;; there isn't a default handler.  
;;; file->state-fcn takes a pathname and returns the state object
;;; for the slurp task (default: return nil).

(defmacro def-slurp-task (name
			  &key ((:default default-handler^)
				'nil)
			       ((:file->state-fcn file->state-fcn^)
				'(\\ (_) nil)))
   (let ((task-var (build-symbol (:< name) *)))
      `(progn
	  (defparameter ,task-var
	      (make-Slurp-task :label ',name
			       :default-handler ,default-handler^
			       :file->state-fcn ,file->state-fcn^))
	  (datafun attach-datafun ,name
	     (defun :^ (_ sym fname)
	        (setf (href (Slurp-task-handler-table ,task-var)
			    sym)
		      (symbol-function fname)))))))

(defvar fload-verbose*            true)		
;;; -- true for message during FLOAD and related ops.

(defvar fload-indent*     0)

(defvar post-file-transduce-hooks* '*not-transducing
  "A list of things to do (i.e., functions of no arguments to call) 
after YTools file transducers finish.")

(defmacro with-post-file-transduction-hooks (&body b)
   `(let ((post-file-transduce-hooks* '()))
       (cleanup-after-file-transduction ,@b)))

(defmacro after-file-transduction (&body b)
   `(cond ((check-file-transduction ',b)
	   (on-list (\\ () ,@b) post-file-transduce-hooks*))))

(defun during-file-transduction ()
   (not (eq post-file-transduce-hooks* '*not-transducing)))

(defmacro setf-during-file-transduction (place val^)
   (let ((save-var (gensym)))
      `(let ((,save-var ,place))
	  (after-file-transduction (\\ () (setf ,place ,save-var)))
	  (setf ,place ,val^))))

(defun check-file-transduction (b)
   (cond ((during-file-transduction) true)
	 (t
	  (cerror "I will skip setting the hook"
	     "Attempt to set post-file-transduction hook when not transducing a file ~%   (~s)"
	     b)
	  false)))

;; --Pathname of file ...
(defvar now-loading*     nil)  ; ... being loaded by 'fload'
(defvar now-compiling* false)  ; ... being compiled by 'fcompl'

(defvar slurping-stack* '())
;;;; (defvar previous-slurp-speclist* '())

;;; The default args for a file-op (such as 'fload' or 'fcompl') are
;;; stored in a vector #(files flags readtable).

(defun file-op-defaults-update (specs possible-flags
				acc-defaults set-defaults)
   (let ((defaults (funcall acc-defaults)))
      (multiple-value-bind (files flags readtab)
	                   (flags-separate specs possible-flags)
	     (funcall set-defaults
		 (vector (cond ((null files) (aref defaults 0))
			       (t files))
			 (cond ((and (null flags) (null files))
				(aref defaults 1))
			       ((memq '- flags)
				!())
			       (t
				flags))
			 (decipher-readtable readtab (aref defaults 2)))))))

(defun decipher-readtable (readtab default-readtab)
   (cond ((eq readtab ':missing)
	  (cond ((and default-readtab
		      (not (eq default-readtab
			       *readtable*)))
		 (format *error-output*
			 "Readtable ~s will be used for this file operation~%"
			 default-readtab)
		 default-readtab)
		(t
		 *readtable*)))
	 (t
	  (name->readtable readtab))))

;;; True if we're in the midst of an 'fload' or 'fcompl'
(defvar file-op-in-progress* false)

(defmacro cleanup-after-file-transduction (&body b)
   `(unwind-protect (progn ,@b)
       (dolist (h (nreverse post-file-transduce-hooks*))
	  (funcall h))))

;;; Returns three values: filespecs, flags, and readtable
;;; If readtable is missing, the value is :missing.
(defun flags-separate (args possible-flags)
   (let ((flags !())
	 (readtab (memq ':readtable args)))
      (cond (readtab
	     (setq args (nconc (ldiff args readtab)
			       (cddr readtab)))
	     (setq readtab (cadr readtab)))
	    (t (setq readtab ':missing)))
      (do ((al args (cond (flags-done al) (t (cdr al))))
	   (flags-done false)
	   fname interned-flag)
	  ((or flags-done (null al))
	   (values al (reverse flags) readtab))
         (cond ((is-Symbol (car al))
		(setq fname
		      (symbol-name (car al)))
		(setq flags-done (not (char= (elt fname 0) #\-))))
	       (t
		(setq flags-done true)))
	 (cond ((not flags-done)
		(setq interned-flag
		      (intern fname ytools-package*))
		(cond ((memq interned-flag possible-flags)
		       (setq flags (cons interned-flag flags)))
		      (t
		       (cerror "I'll ignore it"
			   "Unexpected flag ~s; expected one of ~a"
			      (car al)
			      (mapcar (lambda (flag)
					 (intern (symbol-name flag)
						 *package*))
				      possible-flags)))))))))

(defvar fload-show-actual-pathnames* true)

(defun file-op-message (beg-message pn real-pn end-message)
   (if fload-verbose*
       (progn
	  (print-spaces fload-indent* *query-io*)
	  (format *query-io* "~a " beg-message)
	  (cond (pn
		 (format *query-io* "~a" (namestring pn))))
	  (cond ((and fload-show-actual-pathnames*
		     real-pn
		     (not (equal real-pn pn)))
		 (format *query-io* "~%")
		 (print-spaces
		     (+ fload-indent* (length beg-message) -2)
		     *query-io*)))
	  (format *query-io* "~a~%" end-message))))

(defmacro in-readtable (name)
  `(eval-when (:compile-toplevel :load-toplevel :slurp-toplevel :execute)
      (setq *readtable* (name->readtable ',name))))

(defun name->readtable (name)
   (cond ((not name) lisp-readtable*)
	 ((symbolp name)
	  (let ((rt (or (named-readtable name)
			(eval name))))
	     (cond ((typep rt 'readtable)
		    rt)
		   (t (error "in-readtable: ~s is not a readtable" rt)))))
	 (t
	  (error "in-readtable: ~s is not the name of a readtable"
		 name))))

(defmacro in-regime (pkg &optional rt)
   `(progn (in-package ,pkg)
	   (in-readtable ,(or rt pkg))))

(defvar now-slurping* false)

(defvar hidden-slurp-tasks* !())

;;; 'states' is a list of data structures, the same length as
;;; 'slurp-tasks'.  Each element of 'states' serves as a blackboard
;;; for the corresponding task.  'stream-init', if not false, is
;;; a function to apply to the stream when it is opened.
;;; The order of the slurp-tasks is irrelevant, and may change
;;; as the process progresses.
(defun file-slurp (pn slurp-tasks stream-init)   ;;;; states
   (cond ((not (null slurp-tasks))
	  (let ((post-file-transduce-hooks* !()))
	     (with-open-file (s pn :direction ':input)
		(cleanup-after-file-transduction
		   (let ((fload-indent*  0)
			 (now-loading*  false)
			 (now-compiling* false)
			 (now-slurping*   pn)
			 (slurping-stack* (cons pn slurping-stack*))
			 #+:excl (excl:*source-pathname* pn)
			 #+:excl (excl:*record-source-file-info* nil)
			 (*package* *package*)
			 (*readtable* *readtable*)
			 (slurp-states
			    (mapcar
			       (\\ (slurp-task)
				  (funcall (Slurp-task-file->state-fcn
						   slurp-task)
					   pn))
			       slurp-tasks))
			 (vis-tasks
			       (remove-if (\\ (k)
					     (memq (Slurp-task-label
						      k)
						   hidden-slurp-tasks*))
					  slurp-tasks)))
		      (cond ((not (null vis-tasks))
			     (file-op-message
				 (format nil "Slurping ~s"
					     (mapcar #'Slurp-task-label
						     vis-tasks))
				 pn false "...")))
;;;;		      (cond ((equal slurped-pn*
;;;;				    (->pathname "tezt-s.lisp"))
;;;;			     (setq slurped-pn* pn slurp-tasks* slurp-tasks)
;;;;			     (break "Slurping")))
		      (cond (stream-init
			     (funcall stream-init s)))
		      (do ((form (read s false eof*) (read s false eof*))
			   (tasks slurp-tasks)
			   (states slurp-states))
			  ((or (eq form eof*)
			       (progn
				  (multiple-value-setq
					(tasks states)
					(form-slurp form tasks states))
				  (null tasks)))
			   slurp-states)
;;;;			(format t "Slurped form ~s~%" form)
			)
		      (cond ((not (null vis-tasks))
			     (file-op-message "...slurped" pn false ""))))))))
	 (t !())))

(defun forms-slurp (forms tasks states)
      (do ((l forms (cdr l)))
	  ((or (null l)
	       (null tasks))
	   (values tasks states))
	 (multiple-value-setq (tasks states)
	                      (form-slurp (car l) tasks states))))

;;; General slurpers take 3 args: the form, the task, and the slurp state
;;; They return two values: the remaining tasks, and their states.
(datafun-table general-slurp-handlers* general-slurper :size 50)

;;; Each element of 'slurp-tasks' is something like :macros, or :header-info
;;; Handler returns t if the task should stop.  So 'form-slurp'
;;; returns the tasks that should continue, plus their corresponding
;;; states.
(defun form-slurp (r slurp-tasks slurp-states)
   (flet ((form-fcn-sym (e)
	     (cond ((and (consp e)
			(is-Symbol (car e)))
		   (car e))
		  (t false))))
      (let ((continuing-tasks !())
	    (continuing-states !())
	    (asym (form-fcn-sym r))
	    (form r))
	 (loop
;;;;	    (format t "tasks = ~s form = ~s ~%"
;;;;		    (mapcar #'Slurp-task-label slurp-tasks) form)
	   ;; Macro-expand until handled generally or
	   ;; handled by all
	   (cond
	     ((or (null slurp-tasks)
		  (not asym))
	      (return (values continuing-tasks continuing-states)))
	     (t
	      (let ((h (href general-slurp-handlers*
			     asym)))
		 (cond (h
			(multiple-value-bind
				      (tl sl)
				      (funcall h form slurp-tasks slurp-states)
			   ;; Odd situation: Some specific
			   ;; handler may have run before
			   ;; the general one was found.
			   (return
			      (values (nconc continuing-tasks tl)
				      (nconc continuing-states sl)))))
		       (t
			(do ((tasks slurp-tasks (cdr tasks))
			     (states slurp-states (cdr states))
			     (unclear-tasks !())
			     (unclear-states !()))
			    ((null tasks)
			     ;; We will try again after
			     ;; macro-expansion --
			     (setq slurp-tasks unclear-tasks)
			     (setq slurp-states unclear-states))
			   ;; Try to run handler --
			   (let ((task (first tasks))
				 (state (first states))
				 (task-done false)
				 (handled-by-task false) h)
			      (setq h (href (Slurp-task-handler-table task)
					    asym))
			      (cond (h
				     (setq handled-by-task true)
				     (setq task-done (funcall h form state)))
				    ((setq h (Slurp-task-default-handler
						   task))
				     (setq handled-by-task true)
				     (setq task-done (funcall h form state))))
			      (cond (handled-by-task
				     (cond ((not task-done)
					    (on-list task
						     continuing-tasks)
					    (on-list state
						     continuing-states))))
				    (t
				     (on-list task unclear-tasks)
				     (on-list state unclear-states)))))
			(cond ((and (not (null slurp-tasks))
				    (macro-function asym))
			       (setq form (macroexpand-1 form))
			       (setq asym (form-fcn-sym form)))
			      (t
			       (return
				   (values (nconc continuing-tasks
						  slurp-tasks)
					   (nconc continuing-states
						  slurp-states))))))))))))))

;;; The idea is that almost every slurp task will treat 'progn'
;;; the same way, so we shouldn't have to create many replicas of
;;; this pattern --
(datafun general-slurper progn
   (defun :^ (form tasks states)
      (forms-slurp (cdr form) tasks states)))

(datafun general-slurper prog1 progn)
(datafun general-slurper prog2 progn)

(datafun general-slurper eval-when-slurping
   (defun :^ (forms tasks states)
      (dolist (e (cdr forms))
	 (eval e))
      (values tasks states)))

(datafun general-slurper eval-when
   (defun :^ (form tasks states)
      (cond ((memq ':slurp-toplevel (cadr form))
	     (dolist (e (cddr form))
	        (eval e))))
     (values tasks states)))

(datafun general-slurper with-packages-unlocked
   (defun :^ (form tasks states)
      (with-packages-unlocked
	 (forms-slurp (cdr form) tasks states))))

(defconstant can-get-write-times*
    #.(not (not (file-write-date
		    (concatenate 'string ytools-home-dir* "files.lisp")))))

(defun pathname-source-version (pn)
  (cond ((is-Pseudo-pathname pn) false)
	(t
	 (let ((rpn (cond ((is-Pathname pn) pn)
			  (t (pathname-resolve pn false)))))
	    (let ((pn-type (Pathname-type rpn)))
	       (cond (pn-type
		      (cond ((equal pn-type obj-suffix*)
			     (get-pathname-with-suffixes
				rpn source-suffixes*))
			    ((probe-file rpn)
			     rpn)
			    (t false)))
		     ((probe-file rpn) rpn)
		     (t (get-pathname-with-suffixes
			   rpn source-suffixes*))))))))

(defun pathname-object-version (pn only-if-exists)
   (let ((ob-pn
	    (pathname-find-associate pn 'obj-version obj-suffix*
				     only-if-exists)))
      (cond ((and (not only-if-exists)
		  (not ob-pn))
	     (cerror "I will treat it as :unknown"
		     "Pathname has no object version: ~s" ob-pn)
	     ':none)
	    (t ob-pn))))

(defun pathname-write-time (pname)
  (setq pname (pathname-resolve pname false))
  (and can-get-write-times*
       (probe-file pname)
       (file-write-date pname)))

;;; pn must be a resolved Pathname, not a YTools Pathname.
(defun get-pathname-with-suffixes (pn suffixes)
   (do ((sfl suffixes (cdr sfl))
	(found false)
	newpn)
       ((or found (null sfl))
	(and found newpn))
      (setq newpn (merge-pathnames
		     (make-Pathname :type (car sfl))
		     pn))
      (cond ((probe-file newpn)
	     (setq found true)))))




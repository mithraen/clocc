;;; -*- Mode: CLtL -*-

;;; run-os-program --

(in-package "MK4")			; Maybe this functionality
					; should be in its own
					; package or CL.ENVIRONMENT.


(define-condition os-program-error (error)
  ((program :reader os-program-error-program
	    :initarg :program)
   (reason :reader os-program-error-reason
	   :initarg :reason)
   )
  (:report (lambda (cnd stream)
	     (format stream "MK4: error cannot run program ~S;~&~A"
		     (os-program-error-program cnd)
		     (os-program-error-reason cnd))))
  )


(defgeneric run-os-program (program
			    &key
			    (arguments ())
			    (input *standard-input*)
			    (output *standard-output*)
			    (error-output *error-output*)
			    &allow-other-keys)
  (:documentation
   "Runs a `command' in the underlying Operating System."))

(defmethod run-os-program ((program t) &key arguments &allow-other-keys)
  (error "run-os-program not implementation for program ~S" program))

;;; end of file -- run-os-program.lisp --

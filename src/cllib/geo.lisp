;;; File: <geo.lisp - 1998-07-31 Fri 12:37:41 EDT sds@mute.eaglets.com>
;;;
;;; Geo.lisp - geographical data processing
;;;
;;; Copyright (C) 1998 by Sam Steingold.
;;; This is open-source software.
;;; GNU General Public License v.2 (GPL2) is applicable:
;;; No warranty; you may copy/modify/redistribute under the same
;;; conditions with the source code. See <URL:http://www.gnu.org>
;;; for details and precise copyright document.
;;;
;;; $Id: geo.lisp,v 1.4 1998/07/31 16:54:23 sds Exp $
;;; $Source: /cvsroot/clocc/clocc/src/cllib/geo.lisp,v $
;;; $Log: geo.lisp,v $
;;; Revision 1.4  1998/07/31 16:54:23  sds
;;; Declared `stream' as a stream in `print-*'.
;;;
;;; Revision 1.3  1998/06/30 13:46:58  sds
;;; Switched to `print-object'.
;;;
;;; Revision 1.2  1998/03/10 18:31:03  sds
;;; Replaced `multiple-value-set*' with `(setf (values ))'.
;;;

(in-package :cl-user)

(eval-when (load compile eval)
  (sds-require "base") (sds-require "url")
  (declaim (optimize (speed 3) (space 0) (safety 3) (debug 3))))

;;;
;;; {{{ Georgaphic Coordinates
;;;

(defun parse-geo-coord (st)
  "Return the number parsed from latitude or longitude (dd:mm:ss[NSEW])
read from the stream."
  (declare (stream st))
  (let* ((sig 1) (cc (+ (read st) (/ (read st) 60.0d0)))
	 (lt (read st)) se nn)
    (if (numberp lt) (setq se lt nn 0 lt (string (read st)))
	(setf (values se nn)
	      (parse-integer (setq lt (string lt)) :junk-allowed t)))
    (unless se (setq se 0))
    (setq sig (cond ((or (char-equal (schar lt nn) #\n)
			 (char-equal (schar lt nn) #\e)) 1)
		    ((or (char-equal (schar lt nn) #\s)
			 (char-equal (schar lt nn) #\w)) -1)
		    (t (error "Wrong sign designation: `~a'. ~
Must be one of [N]orth, [S]outh, [E]ast or [W]est." (schar lt nn)))))
    (double-float (* sig (+ cc (/ se 3600d0))))))

(defun geo-location (str &key (start 0))
  "Return the latitude and longitude as two numbers from a string of
type \"48:51:00N 2:20:00E\". Return 2 values - latitude and longitude."
  (declare (simple-string str) (fixnum start))
  (setq str (nsubstitute #\Space #\: (string str))
	str (nsubstitute #\Space #\, (string str)))
  (with-input-from-string (st str :start start)
    (values (parse-geo-coord st) (parse-geo-coord st))))

(defun print-geo-coords (obj &optional (ar1 t) (ar2 t))
  "Print the geographic coordinates to the stream.
If the first two arguments are numbers, print them to the third argument.
Otherwise, the print the slots LAT and LON of the first argument to the
second argument."
  (let (lat lon str)
    (if (and (realp obj) (realp ar1)) (setq lat obj lon ar1 str ar2)
	(setq lat (slot-value obj 'lat) lon (slot-value obj 'lon) str ar1))
    (format str "~9,5f ~a  ~9,5f ~a" lat (if (minusp lat) #\S #\N) lon
	    (if (minusp lon) #\W #\E))))

;;;
;;; }}}{{{ Geo-Data
;;;

(eval-when (load compile eval)
(defstruct (geo-data (:conc-name geod-))
  (name "??" :type string)	; the name of the place
  (pop 0 :type (real 0 *))	; population
  (lat 0.0d0 :type double-float) ; latitude
  (lon 0.0d0 :type double-float) ; longitude
  (zip nil :type list))		; list of zip codes.
)

(defmethod print-object ((gd geo-data) (stream stream))
  "Print the geo-data."
  (when *print-readably* (return-from print-object (call-next-method)))
  (format stream "Place: ~a~%Population: ~12:d;~30tLocation: "
          (geod-name gd) (geod-pop gd))
  (print-geo-coords gd stream)
  (format stream "~%Zip Code~p:~{ ~d~}~%" (length (geod-zip gd))
          (geod-zip gd)))

(defcustom *census-gazetteer-url* url
  (make-url :prot "http" :host "www.census.gov" :path "/cgi-bin/gazetteer?")
  "*The URL to use to get the cite information.")

(defun cite-info (&key (url *census-gazetteer-url*) city state zip (out t))
  "Get the cite info from the U.S. Gazetteer.
Print the results to the stream OUT (defaults to T, discard if NIL)
and return a list of geo-data."
  (setq url (if (url-p url) (copy-url url) (url url)))
  (unless (or city state zip)
    (error "You must specify at least one of :city, :state or :zip~%"))
  (flet ((prep (str) (if str (substitute #\+ #\Space (string str)) "")))
    (setf (url-path url)
	  (format nil "~acity=~a&state=~a&zip=~a" (url-path url) (prep city)
		  (prep state) (or zip ""))))
  (with-open-url (sock url *readtable* t)
    (skip-search sock "<ul>")
    (do ((str "") res gd (ii 1 (1+ ii)))
	((or (search "</ul>" str)
	     (search "</ul>" (setq str (read-line sock))))
	 (nreverse res))
      (declare (type (unsigned-byte 20) ii) (simple-string str))
      ;; name
      (setq gd (make-geo-data :name (strip-html-markup str))
	    str (read-line sock))
      ;; population
      (setf (geod-pop gd) (parse-integer str :junk-allowed t :start
					 (1+ (position #\: str))))
      ;; location
      (setq str (nsubstitute #\Space #\: (read-line sock))
	    str (nsubstitute #\Space #\, str)
	    str (nsubstitute #\Space #\< str))
      (with-input-from-string (st str)
	(read st)
	(setf (geod-lat gd) (* (read st) (if (eq 'n (read st)) 1 -1))
	      (geod-lon gd) (* (read st) (if (eq 'w (read st)) 1 -1))))
      ;; zip
      (setq str (read-line sock))
      (setf (geod-zip gd)
	    (if (search "Zip Code" str)
		(with-input-from-string (st str :start (1+ (position #\: str)))
		  (do (rr re) ((null (setq rr (read st nil nil)))
			       (nreverse re))
		    (when (numberp rr) (push rr re))))
		(list zip)))
      (read-line sock) (setq str (read-line sock)) (push gd res)
      (when out (format out "~%~:d. ~a" ii gd)))))

(defcustom *weather-url* url
  (make-url :prot "telnet" :port 3000 :host "mammatus.sprl.umich.edu")
  "*The url for the weather information.")

(defun weather-report (code &key (out t) (url *weather-url*))
  "Print the weather report for CODE to OUT."
  (setq url (if (url-p url) (copy-url url) (url url)))
  (setf (url-path url) (format nil "/~a//x" code))
  (with-open-url (sock url nil)
    (do (rr)
	((eq +eof+ (setq rr (read-line sock nil +eof+))))
      (format out "~a~%" rr))))

;;;
;;; Countries
;;;

(eval-when (load compile eval)
(defstruct (country)
  "The country structure - all the data about a country you can think of."
  (name "" :type simple-string)	; name
  (fips nil :type symbol)	; FIPS PUB 10-4 code (US Dept of State)
  (iso2 nil :type symbol)	; ISO 3166: Codes for the Representation
  (iso3 nil :type symbol)	; of Names of Countries. 2- and 3- letters
  (isod 0 :type fixnum)		; ISO 3166: number
  (inet nil :type symbol)	; Internet Domain
  (incl nil :type (or null country)) ; Included in
  (captl nil :type (or null simple-string)) ; Capital
  (area 0.0d0 :type (double-float 0.0 *)) ; Area, in sq km
  (frnt 0.0d0 :type (double-float 0.0 *)) ; fontier length, in km
  (cstl 0.0d0 :type (double-float 0.0 *)) ; coastline, in km
  (lat 0.0d0 :type double-float) ; Latitude
  (lon 0.0d0 :type double-float) ; Longitude
  (pop 0 :type integer)		; population
  (birth 0.0d0 :type (double-float 0.0 *)) ; birth rate
  (death 0.0d0 :type (double-float 0.0 *)) ; death rate
  (mgrtn 0.0d0 :type double-float) ; net migration rate
  (fert 0.0d0 :type (double-float 0.0 *)) ; fertility rate per woman
  (life 0.0d0 :type (double-float 0.0 *)) ; life expectancy at birth
  (gdp 0.0d0 :type (double-float 0.0 *)) ; GDP, in $$
  (gdpgr nil :type (or null double-float)) ; GDP growth, in %%
  (gdppc 0.0d0 :type (double-float 0.0 *)) ; GDP per capita, in $$
  (note nil :type (or null simple-string)) ; ISO Note
  (lctn nil :type (or null simple-string)) ; Location Description
  (dspt nil :type (or null simple-string)) ; Territorial Disputes
  (clmt nil :type (or null simple-string)) ; Climate
  (rsrc nil :type (or null simple-string)) ; Natural Resources
  (ethn nil :type (or null simple-string)) ; ethnic divisions
  (lang nil :type (or null simple-string)) ; languages
  (rlgn nil :type (or null simple-string)) ; religions
  ))

(defmethod print-object ((ntn country) (stream stream))
  (when *print-readably* (return-from print-object (call-next-method)))
  (format stream "~a~@[ (~a)~] [~a ~a] [ISO: ~a ~a ~d]~@[ part of ~a~]
Location: "
          (country-name ntn) (country-captl ntn) (country-fips ntn)
          (country-inet ntn) (country-iso2 ntn) (country-iso3 ntn)
          (country-isod ntn) (and (country-incl ntn)
                                  (country-name (country-incl ntn))))
  (print-geo-coords ntn stream)
  (format stream "~%Population: ~15:d  B: ~5f  D: ~5f  M: ~5f  Net: ~5f
Fertility: ~5f births/woman   Life expectancy at birth: ~5f years
Area: ~1/comma/ sq km  Frontiers: ~1/comma/ km  Coastline: ~1/comma/ km
GDP: ~2,15:/comma/ (~f $/cap~@[; %~4f growth~])
~@[ * Location: ~a~%~]~@[ * Disputes: ~a~%~]~
~@[ * Climate: ~a~%~]~@[ * Resources: ~a~%~]~@[ * Ethnic divisions: ~a~%~]~
~@[ * Languages: ~a~%~]~@[ * Religions: ~a~%~]~@[[~a]~%~]"
          (country-pop ntn) (country-birth ntn) (country-death ntn)
          (country-mgrtn ntn) (country-pop-chg ntn) (country-fert ntn)
          (country-life ntn) (country-area ntn) (country-frnt ntn)
          (country-cstl ntn) (country-gdp ntn) (country-gdppc ntn)
          (country-gdpgr ntn) (country-lctn ntn) (country-dspt ntn)
          (country-clmt ntn) (country-rsrc ntn) (country-ethn ntn)
          (country-lang ntn) (country-rlgn ntn) (country-note ntn)))

(defsubst country-pop-chg (ntn)
  "Return the net population change, per 1000."
  (declare (type country ntn))
  (- (+ (country-birth ntn) (country-mgrtn ntn)) (country-death ntn)))

(defcustom *geo-code-url* url
  (make-url :prot "http" :host "www.odci.gov" :path
	    "/cia/publications/factbook/appf.html")
  "*The URL with the table of the codes.")
(defcustom *geo-info-template* simple-string
  "http://www.odci.gov/cia/publications/factbook/~a.html"
  "*The string for generating the URL for getting information on a country.")
(defcustom *country-list* list nil "*The list of known countries.")
(defcustom *country-file* pathname (merge-pathnames "country.dat" *lisp-dir*)
  "The file with the country data.")

(defsubst find-country (slot value &optional (ls *country-list*)
			(test (cond ((member slot '(name cap note)) #'search)
				    ((member slot '(isod pop)) #'=)
				    ((member slot '(area frnt lat lon gdp))
				     (lambda (va sl) (< (car va) sl (cdr va))))
				    (#'eq))))
  "Get the COUNTRY struct corresponding to the given SLOT VALUE.
Returns the list of all countries satisfying the condition.
Looks in list LS, which defaults to `*country-list*'.  If slot value
is a float, such as the GDP, VALUE is a cons with the range.
  (find-country SLOT VALUE &optional LS TEST)"
  (declare (symbol slot) (type (function (t t) t) test) (list ls))
  (mapcan (lambda (nn)
	    (when (funcall test value (slot-value nn slot)) (list nn)))
	  ls))

(defun save-restore-country-list (&optional (save t))
  "Save or restore `*country-list*'."
  (if (and save *country-list*) (write-to-file *country-list* *country-file*)
      (setq *country-list* (read-from-file *country-file*)))
  (values))

(defun str-core (rr)
  "Get the substring of the string from the first `>' to the last `<'."
  (declare (simple-string rr) (values (or null simple-string)))
  (let ((cc (subseq rr (1+ (position #\> rr))
		    (position #\< rr :from-end t :start 2))))
    (cond ((string= "-" cc) "NIL") ((string= "<BR>" cc) nil)
	  ((string-trim +whitespace+ cc)))))

(defun read-some-lines (st)
  "Read some lined from tag to tag."
  (declare (stream st) (values (or null simple-string)))
  (do* ((rr (read-line st) (read-line st))
	(cp (position #\< rr :from-end t :start 2) (position #\< rr))
	(cc (subseq rr (1+ (position #\> rr)) cp)
	    (concatenate 'string cc " " (subseq rr 0 cp))))
       (cp (if (char= #\& (schar cc 0)) nil (string-trim +whitespace+ cc)))
    (declare (simple-string rr cc))))

(defun fetch-country-list ()
  "Initialize `*country-list*' from `*geo-code-url*'."
  (format t "~&Reading `~a'" *geo-code-url*)
  (with-open-url (st *geo-code-url* *readtable* t)
    ;; (with-open-file (st "/home/sds/lisp/wfb-appf.htm" :direction :input)
    (skip-search st "Entity")
    (skip-search st "</TR>")
    (do (res)
	((search "</TABLE>" (skip-blanks st) :test #'char=)
	 (setq *country-list* (nreverse res)))
      (princ ".") (force-output)
      (push (make-country
	     :name (read-some-lines st)
	     :fips (kwd (str-core (read-line st)))
	     :iso2 (kwd (str-core (read-line st)))
	     :iso3 (kwd (str-core (read-line st)))
	     :isod (or (read-from-string (str-core (read-line st))) 0)
	     :inet (kwd (str-core (read-line st)))
	     :note (read-some-lines st)) res)))
  (format t "~d countries.~%" (length *country-list*))
  (dolist (nn *country-list*)	; set incl
    (when (country-note nn)
      (format t "~a: ~a~%" (country-name nn) (country-note nn))
      (do* ((iiw " includes with ") (iiwt " includes with the ") len
	    (pos (or (progn (setq len (length iiwt))
			    (search iiwt (country-note nn)))
		     (progn (setq len (length iiw))
			    (search iiw (country-note nn))))
		 (1+ (or (position #\Space new) (1- (length new)))))
	    (new (if pos (subseq (country-note nn) (+ len pos)))
		 (subseq new pos))
	    (ll (find-country 'name new) (find-country 'name new)))
	   ((or (null new) (zerop (length new)) (= 1 (length ll)))
	    (if (= 1 (length ll))
		(format t "~5tIncluding into --> ~a~%"
			(country-name (setf (country-incl nn) (car ll))))
		(if pos (format t "~10t *** Not found!~%"))))))))

(defun dump-country (ntn &rest opts)
  "Dump the URL for the country."
  (declare (type country ntn))
  (apply #'dump-url (url (format nil *geo-info-template* (country-fips ntn)))
	 opts))

(defun view-country (&rest find-args)
  (let ((ntn (if (country-p (car find-args)) (car find-args)
		 (car (apply #'find-country find-args)))))
    (view-url (format nil *geo-info-template* (country-fips ntn)))))

(defmacro dump-find-country ((&rest find-args) (&rest dump-args &key (out t)
						&allow-other-keys))
  "Dump all the URLs for all the relevant countries."
  (remf dump-args :out)
  (dolist (cc (apply #'find-country find-args))
    (let ((st (if (or (and (symbolp out) (fboundp out)) (functionp out))
		  (funcall out cc) out)))
      (format st "~70~~%~a~70~~%" cc)
      (apply #'dump-country cc :out st dump-args))))

(defun update-country (cc)
  "Get the data from the WWW and update the structure."
  (declare (type country cc))
  ;; (setf (country-note cc) (current-time nil))
  (with-open-url (st (url (format nil *geo-info-template* (country-fips cc)))
		     nil t)
    (ignore-errors
      (setf (country-lctn cc) (next-info st "<B>Location:</B>")
	    (values (country-lat cc) (country-lon cc))
	    (geo-location (next-info st "<BR><B>Geographic coordinates:</B>")))
      (skip-to-line st "<b>Area:</b>")
      (setf (country-area cc) (next-info st "<BR><I>total:</I>" 'float))
      (let ((lb (next-info st "<BR><B>Land boundaries:</B>" 'number)))
	(typecase lb
	  (number (setf (country-frnt cc) (double-float lb)))
	  (t (setf (country-frnt cc) (double-float (parse-num (read-line st))))
	     (add-note cc "Borders with: "
		       (next-info st "<BR><I>border countr")))))
      (setf (country-cstl cc) (next-info st "<BR><B>Coastline:</B>" 'float)
	    (country-dspt cc)
	    (next-info st "<BR><B>International disputes:</B>")
	    (country-clmt cc) (next-info st "<BR><B>Climate:</B>")
	    (country-rsrc cc) (next-info st "<BR><B>Natural resources:</B>")
	    (country-pop cc) (next-info st "<B>Population:</B>" 'number)
	    (country-birth cc) (next-info st "<BR><B>Birth rate:</B>" 'float)
	    (country-death cc) (next-info st "<BR><B>Death rate:</B>" 'float)
	    (country-mgrtn cc)
	    (next-info st "<BR><B>Net migration rate:</B>" 'float)
	    (country-life cc)
	    (next-info st "<BR><B>Life expectancy at birth:</B>" 'float)
	    (country-fert cc)
	    (next-info st "<BR><B>Total fertility rate:</B>"'float)
	    (country-ethn cc) (next-info st "<BR><B>Ethnic groups:</B>")
	    (country-rlgn cc) (next-info st "<BR><B>Religions:</B>")
	    (country-lang cc) (next-info st "<BR><B>Languages:</B>")
	    (country-captl cc) (next-info  st "<BR><B>Capital:</B>")
	    (country-gdp cc) (next-info st "<BR><B>GDP:</B>" 'float)
	    (country-gdppc cc)
	    (next-info st "<BR><B>GDP per capita:</B>" 'float)
	    ))
    cc))

(defun next-info (str skip &optional type)
  "Get the next object from stream STR, skipping till SKIP, of type TYPE."
  (declare (stream str) (simple-string skip) (symbol type))
  (let ((ln (skip-to-line str skip)))
    (case type (float (double-float (parse-num ln))) (number (parse-num ln))
	  (t (concatenate 'string ln (read-non-blanks str))))))

(defun add-note (cc &rest news)
  "Append a note."
  (declare (type country cc) (list news))
  (setf (country-note cc)
	(apply #'concatenate 'string (country-note cc)
	       #.(string #\Newline) news)))

;(defun true (&rest zz) (declare (ignore zz)) t)
;(defun false (&rest zz) (declare (ignore zz)) nil)

(defun parse-num (st)
  "Parse the number from the string, fixing commas."
  (declare (simple-string st))
  (fill st #\Space :end
	(let ((pp (position-if
		   (lambda (zz) (or (digit-char-p zz) (eql zz #\$))) st)))
	  (when pp (if (digit-char-p (char st pp)) pp (1+ pp)))))
  (nsubstitute #\Space #\% st)
  (do ((pos 0 (and next (1+ next))) next res)
      ((null pos)
       (setf st (apply #'concatenate 'string (nreverse res))
	     (values next pos) (read-from-string st nil nil))
       (and next
	    (* next (case (read-from-string st nil nil :start pos)
		      (trillion 1000000000000) (billion 1000000000)
		      (million 1000000) (t 1)))))
    (push (subseq st pos (setq next (position #\, st :start pos))) res)))

#+sds-ignore
(progn
  (load "lisp/geo")
  (fetch-country-list)
  (dolist (cc *country-list*)
    ;(update-country cc)
    (when (and (zerop (country-gdppc cc))
               (/= 0 (country-gdp cc)) (/= 0 (country-pop cc)))
      (setf (country-gdppc cc) (fround (country-gdp cc) (country-pop cc)))
      (format t " *** ~a~2%" cc)))
  (save-restore-country-list))

(provide "geo")
;;; geo.lisp ends here

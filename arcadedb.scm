;;;; ArcadeDB CHICKEN Scheme Module

;;@project: chicken-arcadedb
;;@version: 0.3 (2022-12-09)
;;@authors: Christian Himpe (0000-0003-2194-6754)
;;@license: zlib-acknowledgement (spdx.org/licenses/zlib-acknowledgement.html)
;;@summary: An ArcadeDB database driver for CHICKEN Scheme

(module arcadedb

  (a-help
   a-server
   a-ready?
   a-version
   a-list
   a-exist?
   a-new
   a-delete
   a-use
   a-using
   a-query
   a-command
   a-schema
   a-script
   a-upload
   a-backup
   a-extract
   a-stats
   a-health
   a-repair
   a-comment)

  (import scheme (chicken base) (chicken io) (chicken string) (chicken process) (chicken pathname) uri-common medea)

(print "\n; arcadedb: call `(a-help)` for a procedure overview.\n")

(define-constant version 0)

(define server (make-parameter #f))

(define secret (make-parameter #f))

(define active (make-parameter #f))

;; Local Functions #############################################################

(define (ok? resp)
  (and resp (string-ci=? "ok" (alist-ref 'result resp))))

(define (result resp)
  (and resp (vector->list (alist-ref 'result resp))))

(define (supported? lang)
  (memq lang '(sql sqlscript cypher gremlin graphql mongo)))

(define (http method endpoint #!key (body '()) (session #f) (notify #t))
  (let* [(curl "curl -s")
         (type (case method ['get  " -X GET"]
                            ['post " -X POST"]))
         (head " -H Content-Type: application/json")
         (sess (if session (string-append " -H " session) "")) 
         (data (if (null? body) "" (string-append " -d '" (json->string body) "'")))
         (resp (with-input-from-pipe (apply string-append curl type head sess data  " --user " (secret) " " (server) endpoint)
                                     (if (eqv? method 'head) read-lines read-json)))]
           (cond ((not resp)
                    (begin (print "No Server Response!") #f))
                 ((and ((list-of? pair?) resp) (alist-ref 'error resp))
                    (begin (when notify (print "Server Error: " (alist-ref 'detail resp))) #f))
                 (else resp))))

;;; Help Message ###############################################################

;;@returns: **void**, prints help about arcadedb module functions.
(define (a-help)
  (print "\n"
         " ????????????????????????????????????????????????????????????\n"
         " ??? ????-ArcadeDB (v" (number->string version) ") ???\n"
         " ????????????????????????????????????????????????????????????\n"
         "\n"
         " A CHICKEN Scheme database driver module egg for ArcadeDB (https://arcadedb.com)\n"
         "\n"
         " (a-help)                         - Display this message\n"
         "\n"
         " (a-server user pass host . port) - Set remote server\n"
         "\n"
         " (a-ready?)                       - Is server ready?\n"
         " (a-version)                      - Server version\n"
         "\n"
         " (a-list)                         - List databases\n"
         " (a-exist? db)                    - Does database exist?\n"
         "\n"
         " (a-new db)                       - Create database\n"
         " (a-delete db)                    - Drop database\n"
         "\n"
         " (a-use db)                       - Connect database\n"
         " (a-using)                        - Connected database\n"
         "\n"
         " (a-query lang query)             - Database query\n"
         " (a-command lang cmd)             - Database command\n"
         "\n"
         " (a-schema)                       - List types\n"
         " (a-script path)                  - Execute script\n"
         " (a-upload path type)             - Upload document\n"
         " (a-backup)                       - Backup database\n"
         " (a-extract url)                  - Route request\n"
         " (a-stats)                        - Database statistics\n"
         " (a-health)                       - Database health\n"
         " (a-repair)                       - Repair database\n"
         " (a-comment [msg])                - Database comment\n"
         "\n"
         " For more info see: https://wiki.call-cc.org/eggref/5/arcadedb\n"))

;;; Server Connection ##########################################################

;;@returns: **alist** with single entry if connection to server using **string**s `user`, `pass`, `host`, and optionally **number** `port`, succeded.
(define (a-server user pass host . port)
  (assert (and (string? user) (string? pass) (string? host)))
  (server (string-append "http://" host ":" (number->string (optional port 2480)) "/api/v1/"))
  (secret (string-append user ":" pass))
  (if (a-ready?) '((arcadedb . "Welcome")) #f))

;;; Server Information #########################################################

;;@returns: **boolean** answering if server is ready.
(define (a-ready?)
  (assert (server))
  (not (not (http 'get '("server")))))

;;@returns: **string** version number of the server, or #f.
(define (a-version)
  (assert (server))
  (let [(resp (http 'get '("databases")))]
    (and resp (alist-ref 'version resp))))

;;; Server Databases ###########################################################

;;@returns: **list** of **symbols** holding available databases, or #f.
(define (a-list)
  (assert (server))
  (let [(resp (result (http 'get '("databases"))))]
    (and resp (map string->symbol resp))))

;;@returns: **boolean** answering if database **symbol** `db` exists.
(define (a-exist? db)
  (assert (and (server) (symbol? db)))
  (let [(resp (http 'get `("exists/" ,(symbol->string db))))]
    (and resp (alist-ref 'result resp))))

;;; Database Management ########################################################

;;@returns: **boolean** that is true if creating new database **symbol** `db` succeded.
(define (a-new db)
  (assert (and (server) (symbol? db)))
  (and (not (a-exist? db)) (ok? (http 'post `("create/" ,(symbol->string db))))))

;;@returns: **boolean** that is true if deleting database **symbol** `db` succeded.
(define (a-delete db)
  (assert (and (server) (symbol? db)))
  (when (eqv? db (active)) (active #f))
  (and (a-exist? db) (ok? (http 'post `("drop/" ,(symbol->string db))))))

;;; Database Connection ########################################################

;;@returns: **boolean** that is true if database **symbol** `db` is connected.
(define (a-use db)
  (assert (symbol? db))
  (and (a-exist? db) (ok? (http 'post `("open/" ,(symbol->string db)))) (active db) #t))

;;@returns: **symbol** naming current database, or #f.
(define (a-using)
  (active))

;;; Database Interactions ######################################################

;;@returns: **list** holding the result of **string** `query` in language **symbol** `lang` on current database, or #f.
(define (a-query lang query)
  (assert (and (server) (active) (supported? lang) (string? query)))
  (result (http 'get `("query/" ,(symbol->string (active)) "/" ,(symbol->string lang) "/" ,(uri-encode-string query)))))

;;@returns: **list** holding the result of **string** `cmd` in language **symbol** `lang` on current database, or #f.
(define (a-command lang cmd)
  (assert (and (server) (active) (supported? lang) (string? cmd)))
  (result (http 'post `("command/" ,(symbol->string (active))) body: `((language . ,(symbol->string lang))
                                                                        (command . ,cmd)))))

;;; Database Macros ############################################################

;;@returns: **alist** of type descriptions for current database, or #f.
(define (a-schema)
  (a-query 'sql "SELECT FROM schema:types"))

;;@returns: **list** holding the result of the last statement of the _ArcadeDB SQL_ script in **string** `path`, or #f.
(define (a-script path)
  (assert (string-ci=? "sql" (pathname-extension path)))
  (a-command 'sqlscript (read-string #f (open-input-file path))))

;;@returns: **boolean** that is true if loading _JSON_ file at **string** `path` into current database as **symbol** `type`.
(define (a-upload path type)
  (assert (and (symbol? type) (string? path) (string-ci=? "json" (pathname-extension path))))
  (and (a-command 'sql (string-append "CREATE DOCUMENT TYPE " (symbol->string type) " IF NOT EXISTS;"))
       (a-command 'sql (string-append "INSERT INTO " (symbol->string type) " CONTENT " (read-string #f (open-input-file path)) ";"))
       #t))

;;@returns: **boolean** that is true if backing-up current database.
(define (a-backup)
  (let [(res (a-command 'sql "BACKUP DATABASE;"))]
    (and res (not (null? res)) (ok? (car res)))))

;;@returns: **boolean** that is true if importing from **string** `url` into current database as **symbol** `type`.
(define (a-extract url)
  (assert (string? url))  
  (let [(res (a-command 'sql (string-append "IMPORT DATABASE " url ";")))]
    (and res (not (null? res)) (ok? (car res)))))  

;;@returns: **list**-of-**alist**s reporting statistics on current database, or #f.
(define (a-stats)
  (a-command 'sqlscript "LET $a = CHECK DATABASE;
                         SELECT $a.totalActiveDocuments[0] AS nDocuments,
                                $a.totalActiveVertices[0] AS nVertices,
                                $a.totalActiveEdges[0] AS nEdges, 
                                $a.totalDeletedRecords[0] AS nDeleted;"))

;;@returns: **list**-of-**alist**s reporting health of current database, or #f.
(define (a-health)
  (a-command 'sqlscript "LET $a = CHECK DATABASE;
                         SELECT $a.warnings[0].size() AS nWarnings,
                                $a.totalErrors[0] AS nErrors,
                                $a.corruptedRecords[0].size() AS nCorruptedRecords,
                                $a.invalidLinks[0] AS nInvalidLinks;"))

;;@returns: **boolean** that is true if automatic repair succeeded.
(define (a-repair)
  (not (not (a-command 'sql "CHECK DATABASE FIX;"))))

;;@returns: **string** comment, or `#t` if **string** `msg` is passed.
(define (a-comment . msg)
  (and (a-command 'sql (string-append "CREATE DOCUMENT TYPE sys IF NOT EXISTS;"))
       (if (null? msg) (let [(res (a-query 'sql (string-append "SELECT comment FROM sys WHERE on = \"database\" LIMIT 1;")))]
                         (and res
                              (not (null? res))
                              (not (null? (car res)))
                              (alist-ref 'comment (car res))))
                       (let [(str (car msg))]
                         (and (string? str)
                              (a-command 'sql (string-append "UPDATE sys SET comment = \"" str "\" UPSERT WHERE on = \"database\";"))
                              #t)))))
)

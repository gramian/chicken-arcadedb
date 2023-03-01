;;;; ArcadeDB CHICKEN Scheme Module

;;@project: chicken-arcadedb
;;@version: 0.5 (2023-03-01)
;;@authors: Christian Himpe (0000-0003-2194-6754)
;;@license: zlib-acknowledgement (spdx.org/licenses/zlib-acknowledgement.html)
;;@summary: An ArcadeDB database driver for CHICKEN Scheme

(module arcadedb

  (a-help
   a-server
   a-ready?  a-version
   a-list    a-exist?
   a-new     a-delete
   a-use     a-using
   a-query   a-command
   a-schema
   a-script
   a-upload  a-ingest
   a-jaccard
   a-backup
   a-stats   a-health
   a-repair
   a-metadata
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

(define (http method endpoint #!key (body '()) (session #f) (notify #t))
  (let* [(curl "curl -s")
         (type (case method ['get  " -X GET"]
                            ['post " -X POST"]))
         (head " -H 'Content-Type: application/json'")
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
         " ╔══════════════════╗\n"
         " ║ 🐔-ArcadeDB (v" (number->string version) ") ║\n"
         " ╚══════════════════╝\n"
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
         " (a-ingest url type)              - Route request\n"
         " (a-jaccard x y)                  - Jaccard similarity\n"
         " (a-backup)                       - Backup database\n"
         " (a-stats)                        - Database statistics\n"
         " (a-health)                       - Database health\n"
         " (a-repair)                       - Repair database\n"
         " (a-metadata id key value)        - Add metadata\n"
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
  (let [(resp (http 'get '("server?mode=basic")))]
    (and resp (alist-ref 'version resp))))

;;; Server Databases ###########################################################

;;@returns: **list** of **symbols** holding available databases, or #f.
(define (a-list)
  (assert (server))
  (let [(resp (result (http 'post '("server") body: `((command . ,(string-append "list databases "))))))]
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
  (and (not (a-exist? db)) (ok? (http 'post '("server") body: `((command . ,(string-append "create database " (symbol->string db))))))))

;;@returns: **boolean** that is true if deleting database **symbol** `db` succeded.
(define (a-delete db)
  (assert (and (server) (symbol? db)))
  (when (eqv? db (active)) (active #f))
  (and (a-exist? db) (ok? (http 'post '("server") body: `((command . ,(string-append "drop database " (symbol->string db))))))))

;;; Database Connection ########################################################

;;@returns: **boolean** that is true if database **symbol** `db` is connected.
(define (a-use db)
  (assert (symbol? db))
  (and (a-exist? db) (active db) #t))

;;@returns: **symbol** naming current database, or #f.
(define (a-using)
  (active))

;;; Database Interactions ######################################################

;;@returns: **list** holding the result of **string** `query` in language **symbol** `lang` on current database, or #f.
(define (a-query lang query)
  (assert (and (server) (active) (memq lang '(sql cypher gremlin graphql mongo)) (string? query)))
  (result (http 'get `("query/" ,(symbol->string (active)) "/" ,(symbol->string lang) "/" ,(uri-encode-string query)))))

;;@returns: **list** holding the result of **string** `cmd` in language **symbol** `lang` on current database, or #f.
(define (a-command lang cmd)
  (assert (and (server) (active) (memq lang '(sql sqlscript cypher gremlin graphql mongo)) (string? cmd)))
  (result (http 'post `("command/" ,(symbol->string (active))) body: `((language . ,(symbol->string lang))
                                                                        (command . ,cmd)))))

;;; Database Macros ############################################################

;;@returns: **alist** of type descriptions for current database, or #f.
(define (a-schema)
  (a-query 'sql "SELECT FROM schema:types"))

;;@returns: **list** holding the result of the last statement of the _ArcadeDB SQL_ script in **string** `path`, or #f.
(define (a-script path)
  (assert (and (string? path) (string-ci=? "sql" (pathname-extension path))))
  (a-command 'sqlscript (read-string #f (open-input-file path))))

;;@returns: **boolean** that is true if loading _JSON_ file at **string** `path` into current database as **symbol** `type` succeeded.
(define (a-upload path type)
  (assert (and (symbol? type) (string? path) (string-ci=? "json" (pathname-extension path))))
  (and (a-command 'sql (string-append "CREATE DOCUMENT TYPE " (symbol->string type) " IF NOT EXISTS;"))
       (a-command 'sql (string-append "INSERT INTO " (symbol->string type) " CONTENT " (read-string #f (open-input-file path)) ";"))
       #t))

;;@returns: **boolean** that is true if importing from **string** `url` into current database as **symbol** `type` succeeded.
(define (a-ingest url type)
  (assert (and (string? url) (symbol? type))) 
  (let* [(res (a-command 'sql (string-append "IMPORT DATABASE " url " WITH documentType = '" (symbol->string type) "';")))]
    (and res (not (null? res)) (ok? (car res)))))

;;@returns **flonum** being the Jaccard similarity index, given a **symbol** `type` and two **symbol** arguments `x` and `y`.
(define (a-jaccard type x y)
  (assert (and (symbol? type) (symbol? x) (symbol? y)))
  (cdaar (a-command 'sqlscript (string-append "LET $t = SELECT unionall(" (symbol->string x) ") AS x, unionall(" (symbol->string y) ") AS y FROM " (symbol->string type)";"
                                              "SELECT intersect($t[0].x,$t[0].y).size().asFloat() / unionall($t[0].x,$t[0].y).size().asFloat();"))))

;;@returns: **boolean** that is true if backing-up current database succeeded.
(define (a-backup)
  (let [(res (a-command 'sql "BACKUP DATABASE;"))]
    (and res (not (null? res)) (ok? (car res)))))

;;@returns: **list**-of-**alist**s reporting statistics on current database, or #f.
(define (a-stats)
  (a-command 'sqlscript "LET a = CHECK DATABASE;
                         SELECT $a.totalActiveDocuments[0] AS nDocuments, $a.totalActiveVertices[0] AS nVertices, $a.totalActiveEdges[0] AS nEdges, $a.totalDeletedRecords[0] AS nDeleted;"))

;;@returns: **list**-of-**alist**s reporting health of current database, or #f.
(define (a-health)
  (a-command 'sqlscript "LET a = CHECK DATABASE;
                         SELECT $a[0].warnings.size() AS nWarnings, $a[0].totalErrors AS nErrors, $a[0].corruptedRecords.size() AS nCorrupted, $a[0].invalidLinks AS nInvalid;"))

;;@returns: **boolean** that is true if automatic repair succeeded.
(define (a-repair)
  (not (not (a-command 'sql "CHECK DATABASE FIX;"))))

;;@returns: **boolean** that is true if adding custom attribute with **symbol** `key` and **string** `value` to type or property **symbol** `id` succeeded.
(define (a-metadata id key value)
  (assert (and (symbol? id) (symbol? key) (or (string? value) (number? value))))
  (and (a-command 'sql (string-append "ALTER " (if (substring-index "." (symbol->string id)) "PROPERTY" "TYPE") " " (symbol->string id)
                                      " CUSTOM " (symbol->string key) " = " (if (string? value) (string-append "\"" value "\"") (number->string value)) ";")) #t))

;;@returns: **string** comment, or `#t` if **string** `msg` is passed.
(define (a-comment . msg)
  (and (a-command 'sql (string-append "CREATE DOCUMENT TYPE sys IF NOT EXISTS;"))
       (if (null? msg) (let [(res (a-query 'sql (string-append "SELECT comment FROM sys WHERE on = \"database\" LIMIT 1;")))]
                         (and res (not (null? res)) (not (null? (car res))) (alist-ref 'comment (car res))))
                       (let [(str (car msg))]
                         (and (string? str) (a-command 'sql (string-append "UPDATE sys SET comment = \"" str "\" UPSERT WHERE on = \"database\";")) #t)))))
) ; end module

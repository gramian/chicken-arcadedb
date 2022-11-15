;;;; ArcadeDB CHICKEN Scheme Module

;;@project: chicken-arcadedb
;;@version: 0.2 (2022-11-16)
;;@authors: Christian Himpe (0000-0003-2194-6754)
;;@license: zlib-acknowledgement (spdx.org/licenses/zlib-acknowledgement.html)
;;@summary: An ArcadeDB database driver for CHICKEN Scheme

(module arcadedb

  (a-help

   a-connect

   a-status
   a-healthy?
   a-list
   a-version

   a-exist?
   a-create
   a-open?
   a-open
   a-close
   a-drop

   a-query
   a-command
   a-script

   a-import
   a-describe
   a-load
   a-backup
   a-check
   a-comment)

  (import scheme (chicken base) (chicken io) (chicken string) (chicken process) (chicken pathname) uri-common medea)

(print "\n; arcadedb: call `(a-help)` for a procedure overview.\n")

(define-constant version 0)

(define server (make-parameter #f))

;; Utility Functions ###########################################################

(define (ok? resp)
  (and resp (string-ci=? "ok" (alist-ref 'result resp))))

(define (result resp)
  (and resp (vector->list (alist-ref 'result resp))))

(define (supported? lang)
  (memq lang '(sql cypher gremlin graphql mongo)))

(define (http method endpoint #!key (body '()) (session #f) (notify #t))
  (let* [(curl "curl -s")
         (type (case method ['get  " -X GET"]
                            ['head " -X POST -I"]
                            ['post " -X POST"]))
         (head " -H Content-Type: application/json")
         (sess (if session (string-append " -H " session) "")) 
         (data (if (null? body) "" (string-append " -d '" (json->string body) "'")))
         (resp (with-input-from-pipe (apply string-append curl type head sess data " " (server) endpoint)
                                     (if (eqv? method 'head) read-lines read-json)))]
           (cond ((not resp)
                    (begin (print "No Server Response!") #f))
                 ((and ((list-of? pair?) resp) (alist-ref 'error resp))
                    (begin (when notify (print "Server Error: " (alist-ref 'detail resp))) #f))
                 (else resp))))

;;; Help Message ###############################################################

;;@returns: **void**, prints help on using the arcadedb module.
(define (a-help)
  (print "\n"
         " ╔══════════════════╗\n"
         " ║ 🐔-ArcadeDB (v" (number->string version) ") ║\n"
         " ╚══════════════════╝\n"
         "\n"
         " A CHICKEN Scheme database driver module egg for ArcadeDB (https://arcadedb.com)\n"
         "\n"
         " (a-help)                          - Display this message\n"
         "\n"
         " (a-connect user pass host . port) - Connect remote server\n"
         "\n"
         " (a-status)                        - Cluster configuration\n"
         " (a-healthy?)                      - Is server alive?\n"
         " (a-list)                          - List databases\n"
         " (a-version)                       - Server version\n"
         "\n"
         " (a-exist? db)                     - Does database exist?\n"
         " (a-create db)                     - Create database\n"
         " (a-open? db)                      - Is database open?\n"
         " (a-open db)                       - Open database\n"
         " (a-close db)                      - Close database\n"
         " (a-drop db)                       - Delete database\n"
         "\n"
         " (a-query db lang query)           - Database query\n"
         " (a-command db lang cmd)           - Database command\n"
         " (a-script db path)                - Database script\n"
         "\n"
         " (a-import db url)                 - Import database\n"
         " (a-describe db)                   - List types\n"
         " (a-load db path type)             - Load document\n"
         " (a-backup db)                     - Backup database\n"
         " (a-check db [fix?])               - Check database\n"
         " (a-comment db [msg])              - Database comment\n"
         "\n"
         " For more info see: https://wiki.call-cc.org/eggref/5/arcadedb\n"))

;;; Server Connection ##########################################################

;;@returns: **alist** with single entry if connection to server using **string**s `user`, `pass`, `host`, and optionally **number** `port` was successful; see @1.
(define (a-connect user pass host . port)
  (assert (and (string? user) (string? pass) (string? host)))
  (server (string-append "http://" user ":" pass "@" host ":" (number->string (optional port 2480)) "/api/v1/"))
  (if (a-healthy?) '((arcadedb . "Welcome")) #f))

;;; Server Information #########################################################

;;@returns: **list** holding cluster configuration of the server, or #f.
(define (a-status)
  (assert (server))
  (http 'get '("server")))

;;@returns: **boolean** answering if the server is ready; see @2.
(define (a-healthy?)
  (not (not (a-status))))

;;@returns: **list** of **symbols** holding available databases of the server, of #f.
(define (a-list)
  (assert (server))
  (map string->symbol (result (http 'get '("databases")))))

;;@returns: **string** version number of the server, or #f.
(define (a-version)
  (assert (server))
  (let [(resp (http 'get '("databases")))]
    (and resp (alist-ref 'version resp))))

;;; Database Management ########################################################

;;@returns: **boolean** answering if database **symbol** `db` exists of the server.
(define (a-exist? db)
  (not (not (http 'post `("open/" ,(symbol->string db)) notify: #f))))

;;@returns: **boolean** that is true if creating new database **symbol** `db` on the server was successful.
(define (a-create db)
  (assert (server))
  (ok? (http 'post `("create/" ,(symbol->string db)))))

;;@returns: **boolean** answering if database **symbol** `db` is open on the server.
(define (a-open? db)
  (assert (server))
  (not (not (http 'get `("query/" ,(symbol->string db) "/sql/SELECT%20true") notify: #f))))

;;@returns: **boolean** that is true if opening database **symbol** `db` on the server was successful.
(define (a-open db)
  (assert (server))
  (ok? (http 'post `("open/" ,(symbol->string db)))))

;;@returns: **boolean** that is true if closing database **symbol** `db` on the server was successful.
(define (a-close db)
  (assert (server))
  (ok? (http 'post `("close/" ,(symbol->string db)))))

;;@returns: **boolean** that is true if deleting database **symbol** `db` on the server was successful.
(define (a-drop db)
  (assert (server))
  (ok? (http 'post `("drop/" ,(symbol->string db)))))

;;; Database Interactions ######################################################

;;@returns: **list** holding the result of **string** `query` in language **symbol** `lang` of database **symbol** `db`.
(define (a-query db lang query)
  (assert (and (supported? lang) (server) (symbol? db) (string? query)))
  (result (http 'get `("query/" ,(symbol->string db) "/" ,(symbol->string lang) "/" ,(uri-encode-string query)))))

;;@returns: **list** holding the result of **string** `cmd` in language **symbol** `lang` to database **symbol** `db`.
(define (a-command db lang cmd)
  (assert (and (supported? lang) (server) (symbol? db) (string? cmd)))
  (result (http 'post `("command/" ,(symbol->string db)) body: `((language . ,(symbol->string lang))
                                                                 (command . ,cmd)))))

;;@returns: **list** holding the result of the last statement of the _ArcadeDB SQL_ script in **string** `path` to database **symbol** `db`; see @3.
(define (a-script db path)
  (assert (and (string? path) (string=? "sql" (pathname-extension path)) (symbol? db) (server)))
  (result (http 'post `("command/" ,(symbol->string db)) body: `((language . "sqlscript")
                                                                 (command . ,(read-string #f (open-input-file path)))))))

;;; Database Macros ############################################################

;;@returns: **boolean** that is true if importing from **string** `url` into database **symbol** `db` as **symbol** `type` on the server was successful.
(define (a-import db url)
  (let [(res (a-command db 'sql (string-append "IMPORT DATABASE " url)))]
    (and res (not (null? res)) (ok? (car res)))))  

;;@returns: **alist** of type descriptions for database **symbol** `db`; see @4.
(define (a-describe db)
  (a-query db 'sql "SELECT FROM schema:types"))

;;@returns: **boolean** that is true if loading _JSON_ file at **string** `path` into database **symbol** `db` as **symbol** `type` on the server was successful.
(define (a-load db type path)
  (assert (and (symbol? type) (string? path) (string-ci=? "json" (pathname-extension path))))
  (and (a-command db 'sql (string-append "CREATE DOCUMENT TYPE " (symbol->string type) " IF NOT EXISTS"))
       (a-command db 'sql (string-append "INSERT INTO " (symbol->string type) " CONTENT " (read-string #f (open-input-file path))))
       #t))

;;@returns: **boolean** that is true if backing-up database **symbol** `db` on the server was successful.
(define (a-backup db)
  (let [(res (a-command db 'sql "BACKUP DATABASE"))]
    (and res (not (null? res)) (ok? (car res)))))

;;@returns: **list**-of-**alist**s integrity check report, and attempts to fix if true **boolean** `fix?` is passed.
(define (a-check db . fix?)
  (a-command db 'sql (string-append "CHECK DATABASE" (if (optional fix? #f) " FIX" ""))))

;;@returns: **string** comment for database **symbol** `db`, or `#t` if **string** `msg` is passed; see @5.
(define (a-comment db . msg)
  (assert (symbol? db))  
  (and (a-command db 'sql (string-append "CREATE DOCUMENT TYPE D IF NOT EXISTS"))
       (if (null? msg) (let [(res (a-query db 'sql (string-append "SELECT comment FROM D WHERE on = \"database\" LIMIT 1")))]
                         (and res
                              (not (null? res))
                              (not (null? (car res)))
                              (alist-ref 'comment (car res))))
                       (let [(str (car msg))]
                         (and (string? str)
                              (a-command db 'sql (string-append "UPDATE D SET comment = \"" str "\" UPSERT WHERE on = \"database\""))
                              #t))))) 

)

;;@1: Return value inspired by: https://docs.couchdb.org/en/3.2.2-docs/intro/api.html?highlight=welcome#server

;;@2: Endpoint name inspired by: https://developers.flur.ee/docs/reference/http/overview/#other-endpoints

;;@3: ArcadeDB SQL reference: https://docs.arcadedb.com/#SQL

;;@4: SQL DESCRIBE comment: https://impala.apache.org/docs/build/html/topics/impala_describe.html

;;@5: SQL COMMENT command: https://impala.apache.org/docs/build/html/topics/impala_comment.html

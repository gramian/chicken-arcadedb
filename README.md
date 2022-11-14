arcadedb (v1)
=============

`arcadedb` is a CHICKEN Scheme egg module providing a driver or REPL
for the [**ArcadeDB**](https://arcadedb.com) database.

## About **ArcadeDB**

**ArcadeDB** is a multi-model NoSQL database providing graph and document models,
while supporting a wide range of data query languages, such as:

* [SQL](https://docs.arcadedb.com/#_sql) (dialect),
* [Cypher](https://opencypher.org/resources/),
* [Gremlin](https://tinkerpop.apache.org/docs/current/),
* [GraphQL](https://graphql.org/),
* [Mongo](https://www.mongodb.com/docs/manual/)

as well as providing a HTTP/JSON/REST API.

### SQL

The native query language of **ArcadeDB** is a dialect of SQL, closely related to
_OrientDB_'s OSQL, which supports the [SQL command categories](https://www.geeksforgeeks.org/sql-ddl-dql-dml-dcl-tcl-commands/):

* **DDL** - Data Definition Language, via `CREATE`, `DROP`, `ALTER`, `TRUNCATE` of `TYPE`s
* **DQL** - Data Query Language, via `SELECT`, `TRAVERSE`, `MATCH`
* **DML** - Data Manipulation Language, via `INSERT`, `UPDATE`, `DROP`, `EXPLAIN`, `PROFILE`

for the remaining categories holds:

* **DCL** - Data Control Language, does not apply due to only [server level users](https://docs.arcadedb.com/#Security)
* **TCL** - Transaction Control Language, via [HTTP REST endpoints](https://docs.arcadedb.com/#HTTP-API)

## About `arcadedb`

The `arcadedb` module implements a driver and console for **ArcadeDB** in
CHICKEN Scheme with the functionality:

* [Server information](#server-information)
* [Database management](#database-management)
* [Database interaction](#database-interaction)
* [Database macros](#database-macros)

### Dependencies

Naturally, `arcadedb` requires a remote or local **ArcadeDB** server:

* [ArcadeDB](https://github.com/ArcadeData/arcadedb/releases/latest)

which in turn requires a Java distribution, i.e. OpenJDK 11.
A local server setup is described below.
Furthermore, the `arcadedb` module requires `curl` for the HTTP requests:

* [curl](http://curl.se)

and imports the `uri-common` egg to url-encode strings,
as well as the `medea` egg to decode JSON:

* [uri-common](https://wiki.call-cc.org/eggref/5/uri-common)
* [medea](https://wiki.call-cc.org/eggref/5/medea)

## Local Server Setup

A local **ArcadeDB** server can be set up via [install](#install) or [container](#container).

### Install

1. Download package: [ArcadeDB **package**](https://github.com/ArcadeData/arcadedb/releases/latest)
2. Extract package: `tar -xf arcadedb-latest.tar.gz`
3. Start server: `ARCADEDB_HOME=/path/to/arcadedb/ bin/server.sh -Darcadedb.server.rootPassword=mypassword &` 
4. Exit server: ``kill `cat bin/arcade.pid` ``

### Container

0. Install [Docker](https://www.docker.com/)
1. Download container: `docker pull arcadedata/arcadedb`
2. Start container: `docker run --rm -d -p 2480:2480 -e JAVA_OPTS="-Darcadedb.server.rootPassword=mypassword --name arcadedb0 arcadedata/arcadedb`
3. Stop container: `docker stop arcadedb0`

## Procedures

### Help Message

#### a-help
```
(a-help)
```
Returns **void**, prints help about using the `arcadedb` module.

### Server Connection

#### a-connect
```
(a-connect user pass host . port)
```
Returns **boolean** answering if connection to server using **string**s `user`,
`pass`, `host`, and optionally **number** `port` was succesful;
returns `#f` if a server error occurs or no response is received.

### Server Information

#### a-status
```
(a-status)
```
Returns **list** holding the cluster configuration of the server;
returns empty **list** `'()` if no replicas are configured;
returns `#f` if a server error occurs or no response is received.

#### a-healthy?
```
(a-healthy?)
```
Returns **boolean** answering if server is ready.

#### a-list
```
(a-list)
```
Returns **list** of **symbol**s holding available databases of the server;
returns `#f` if a server error occurs or no response is received.

#### a-version
```
(a-version)
```
Returns **string** version number of the server;
returns `#f` if a server error occurs or no response is received.

### Database Management

#### a-exist?
```
(a-exist? db)
```
Returns **boolean** answering if database **symbol** `db` exists of the server.

#### a-create
```
(a-create db)
```
Returns **boolean** that is true if creating new database **symbol** `db` on the server was succesful;
returns `#f` if a server error occurs or no response is received.

#### a-open?
```
(a-open? db)
```
Returns **boolean** answering if database **symbol** `db` is open on the server.

#### a-open
```
(a-open db)
```
Returns **boolean** that is true if opening database **symbol** `db` on the server was succesful;
returns `#f` if a server error occurs or no response is received.

#### a-close
```
(a-close db)
```
Returns **boolean** that is true if closing database **symbol** `db` on the server was succesful;
returns `#f` if a server error occurs or no response is received.

#### a-drop
```
(a-drop db)
```
Returns **boolean** that is true if deleting database **symbol** `db` on the server was successful;
returns `#f` if a server error occurs or no response is received.

### Database Interaction

#### a-query
```
(a-query db lang query)
```
Returns **list** holding the result of **string** `query` in language **symbol** `lang` of database **symbol** `db`;
returns `#f` if a server error occurs or no response is received.

#### a-command
```
(a-command db lang cmd)
```
Returns **list** holding the result of **string** `cmd` in language **symbol** `lang` to database **symbol** `db`;
returns `#f` if a server error occurs or no response is received.

#### a-script
```
(a-script db path)
```
Returns **list** holding the result of the last statement of SQL script in **string** `path` to database **symbol** `db`;
returns `#f` if a server error occurs or no response is received.

A SQL script file has to have the file extension `.sql`.

### Database Macros

#### a-import
```
(a-import db url)
```
**boolean** that is true if importing from **string** `url` into database **symbol** `db` on the server was successful;
returns `#f` if a server error occurs or no response is received.

This function can be a minimalistic ETL (Extract-Transform-Load) tool:
If one needs to import data from another database with a HTTP API
and the query can be encoded ([as for **ArcadeDB**](https://docs.arcadedb.com/#HTTP-API)) in the URL,
the extraction and transformation is performed in the remote query,
while the loading corresponds to the import of the query result.
The supported formats are [OrientDB, Neo4J, GraphML, GraphSON, XML, CSV, JSON, RDF](https://docs.arcadedb.com/#Importer).

#### a-describe
```
(a-describe db)
```
Returns **alist** of type descriptions for database **symbol** `db`;
returns `#f` if a server error occurs or no response is received.

This function emulates the SQL `DESCRIBE` statement.

#### a-load
```
(a-load db path type)
```
Returns **boolean** that is true if loading _JSON_ file at **string** `path`
into database **symbol** `db` as **symbol** `type` on the server was successful;
returns `#f` if a server error occurs or no response is received.

#### a-backup
```
(a-backup db)
```
Returns **boolean** that is true if backing-up database **symbol** `db` on the server was successful.

#### a-check
```
(a-check db)
(a-check db fix?)
```
Returns **list**-of-**alist**s integrity check report, attempts to fix if true **boolean** `fix?` is passed.
returns `#f` if a server error occurs or no response is received.

#### a-comment
```
(a-comment db)
(a-comment db msg)
```
Returns **string** current database comment of database **symbol** `db`, if `msg` is not passed;
returns `#t` if **string** `msg` was set as comment for database **symbol** `db` on the server succesfully;
returns `#f` if no comment is set, a server error occurs or no response is received.

This function emulates the SQL `COMMENT ON DATABASE` statement,
by creating a type `D` and upserting or reading the first `comment` property.

## Changelog

* `1` [Initial Release](https://github.com/gramian/chicken-arcadedb) (2022-11-14)

## License

Copyright (c) 2022 _Christian Himpe_ under [zlib-acknowledgement](https://spdx.org/licenses/zlib-acknowledgement.html) license.


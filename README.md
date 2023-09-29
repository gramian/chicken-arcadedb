arcadedb (v0)
=============

`arcadedb` is a CHICKEN Scheme egg module providing a driver or REPL
for the [**ArcadeDB**](https://arcadedb.com) database.

## About **ArcadeDB**

**ArcadeDB** is an open-source multi-model NoSQL database providing the models:

* Key-Value,
* Document,
* Graph,
* Time Series,
* Vector,

while supporting a range of data query languages, such as:

* [SQL](https://docs.arcadedb.com/#_sql) (dialect),
* [Cypher](https://opencypher.org/resources/),
* [Gremlin](https://tinkerpop.apache.org/docs/current/),
* [GraphQL](https://graphql.org/),
* [MQL](https://www.mongodb.com/docs/manual/) (Mongo),

as well as providing a JSON / REST-like / HTTP API.

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
_CHICKEN Scheme_ with the functionality:

* [Server Connection](#server-connection)
* [Server Information](#server-information)
* [Server Databases](#server-databases)
* [Database Management](#database-management)
* [Database Connection](#database-connection)
* [Database Interaction](#database-interaction)
* [Database Macros](#database-macros)

### Runtime Dependencies

Naturally, `arcadedb` requires a (running) remote or local **ArcadeDB** server:

* [ArcadeDB](https://github.com/ArcadeData/arcadedb/releases/latest)

which in turn requires a _Java_ distribution in version 17, i.e. _OpenJDK_ (headless).
A local server setup is described below.
Furthermore, the `arcadedb` module requires `wget` for the HTTP requests:

* [wget](https://www.gnu.org/software/wget/)

during runtime, and imports the `uri-common` egg to url-encode strings,
as well as the `medea` egg to decode JSON:

* [uri-common](https://wiki.call-cc.org/eggref/5/uri-common)
* [medea](https://wiki.call-cc.org/eggref/5/medea)

## Local Server Setup

A local **ArcadeDB** server can be set up via [install](#install) or [container](#container).

### Install

1. Download package: [**ArcadeDB** package](https://github.com/ArcadeData/arcadedb/releases/latest)
2. Extract package: `tar -xf arcadedb-latest.tar.gz`
3. Start server: `bin/server.sh -Darcadedb.server.rootPassword=mypassword &` 
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

#### a-server
```
(a-server user pass host . port)
```
Returns **alist** with single entry if connection to server using **string**s
`user`, `pass`, `host`, and optionally **number** `port`, succeded;
returns `#f` if a server error occurs or no response is received.

### Server Information

#### a-ready?
```
(a-ready?)
```
Returns **boolean** answering if server is ready.

#### a-version
```
(a-version)
```
Returns **string** version number of the server;
returns `#f` if a server error occurs or no response is received.

### Server Databases

#### a-list
```
(a-list)
```
Returns **list** of **symbol**s holding available databases of the server;
returns `#f` if a server error occurs or no response is received.

#### a-exist?
```
(a-exist? db)
```
Returns **boolean** answering if database **symbol** `db` exists on the server.

### Database Management

#### a-new
```
(a-new db)
```
Returns **boolean** that is true if creating new database **symbol** `db` succeded;
returns `#f` if a server error occurs or no response is received.

This command can only be executed by the root or admin user.

#### a-delete
```
(a-delete db)
```
Returns **boolean** that is true if deleting database **symbol** `db` succeded;
returns `#f` if a server error occurs or no response is received.

This command can only be executed by the root or admin user.

### Database Connection

#### a-use
```
(a-use db)
```
Returns **boolean** that is true if database **symbol** `db` is connected;
returns `#f` if a server error occurs or no response is received.

#### a-using
```
(a-using)
```
Returns **symbol** naming current database;
returns `#f` if no database is connected.

### Database Interaction

#### a-query
```
(a-query lang query)
```
Returns **list** holding the result of **string** `query` in language **symbol** `lang` on current database;
returns `#f` if a server error occurs or no response is received.

Valid `lang` **symbols** are: `sql`, `sqlscript`, `cypher`, `gremlin`, `graphql`, `mongo`.

#### a-command
```
(a-command lang cmd)
```
Returns **list** holding the result of **string** `cmd` in language **symbol** `lang` on current database;
returns `#f` if a server error occurs or no response is received.

Valid `lang` **symbols** are: `sql`, `sqlscript`, `cypher`, `gremlin`, `graphql`, `mongo`.

### Database Macros

#### a-config
```
(a-config)
```
Returns **alist** of type descriptions for current database infos;
returns `#f` if a server error occurs or no response is received.

#### a-schema
```
(a-schema)
```
Returns **alist** of type descriptions for current database schema;
returns `#f` if a server error occurs or no response is received.

This function emulates the SQL `DESCRIBE` statement.

#### a-script
```
(a-script path)
```
Returns **list** holding the result of the last statement of SQL script in **string** `path` executed on current  database;
returns `#f` if a server error occurs or no response is received.

A SQL script file has to have the file extension `.sql`.

#### a-upload
```
(a-upload path type)
```
Returns **boolean** that is true if uploading _JSON_ file at **string** `path`
into current database as **symbol** `type` succeded;
returns `#f` if a server error occurs or no response is received.

A JSON script file has to have the file extension `.json`.

#### a-ingest
```
(a-ingest url)
```
Returns **boolean** that is true if importing from **string** `url` into current database succeded;
returns `#f` if a server error occurs or no response is received.

This function can be a minimalistic ETL (Extract-Transform-Load) tool:
If one needs to import data from another database with a HTTP API
and the query can be encoded ([as for **ArcadeDB**](https://docs.arcadedb.com/#HTTP-API)) in the URL,
the extraction and transformation is performed in the remote query,
while the loading corresponds to the import of the query result.
The supported formats are [OrientDB, Neo4J, GraphML, GraphSON, XML, CSV, JSON, RDF](https://docs.arcadedb.com/#Importer).

#### a-jaccard
```
(a-jaccard type x y)
```
Returns **flonum** being the [Jaccard similarity index](https://en.wikipedia.org/wiki/Jaccard_index),
given a **symbol** `type` and two **symbol** arguments `x` and `y`.

#### a-backup
```
(a-backup)
```
Returns **boolean** that is true if backing-up current database succeded.

#### a-stats
```
(a-stats)
```
Returns **list**-of-**alist**s reporting statistics on current database;
returns `#f` if a server error occurs or no response is received.

#### a-health
```
(a-health)
```
Returns **list**-of-**alist**s reporting health of current database;
returns `#f` if a server error occurs or no response is received.

#### a-repair
```
(a-repair)
```
Returns **boolean** that is true if automatic repair succeeded.

#### a-metadata
```
(a-metadata id key value)
```
Returns **boolean** that is true if adding custom attribute
with **symbol** `key` and **string** `value` to type or property **symbol** `id` succeeded.

#### a-comment
```
(a-comment)
(a-comment msg)
```
Returns **string** current database comment of current database, if `msg` is not passed;
returns `#t` if setting **string** `msg` as comment for current database succeded;
returns `#f` if no comment is set, a server error occurs or no response is received.

This function emulates the SQL `COMMENT ON DATABASE` statement,
by creating a type `sys` and upserting or reading the first `comment` property.

## Changelog

* `0.1` [Initial Release](https://github.com/gramian/chicken-arcadedb) (2022-11-15)
* `0.2` [Minor Update](https://github.com/gramian/chicken-arcadedb) (2022-11-16)
* `0.3` [Major Update](https://github.com/gramian/chicken-arcadedb) (2022-12-09)
* `0.4` [Minor Update](https://github.com/gramian/chicken-arcadedb) (2023-01-16)
* `0.5` [Major Update](https://github.com/gramian/chicken-arcadedb) (2023-03-01)
* `0.6` [Major Update](https://github.com/gramian/chicken-arcadedb) (2023-05-05)
* `0.6` [Minor Update](https://github.com/gramian/chicken-arcadedb) (2023-09-29)

## License

Copyright (c) 2022 _Christian Himpe_ under [zlib-acknowledgement](https://spdx.org/licenses/zlib-acknowledgement.html) license.

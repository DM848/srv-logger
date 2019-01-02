include "srv-interface.iol"
include "service-mesh.iol"
include "time.iol"
include "console.iol"
include "runtime.iol"
include "database.iol"

// single is the default execution modality (so the execution construct can be omitted),
// which runs the program behaviour once. sequential, instead, causes the program behaviour
// to be made available again after the current instance has terminated. This is useful,
// for instance, for modelling services that need to guarantee exclusive access to a resource.
// Finally, concurrent causes a program behaviour to be instantiated and executed whenever its
// first input statement can receive a message.
//
// execution { single | concurrent | sequential }
execution { sequential }

// The input port specifies how your service can be reached. However, since we use
// Docker containers, the port here should not be set as it is exposed in the Dockerfile.
inputPort LoggerInput {
  Location: "socket://localhost:8888/"
  Protocol: http
  Interfaces: 
    LoggerInterface, 
    ServiceMeshInterface
}

constants {
    dbHost = "LOGGER_DB_HOST",
    dbName = "LOGGER_DB_NAME",
    dbUser = "LOGGER_DB_USER",
    dbPort = "LOGGER_DB_PORT",
    dbPwd  = "LOGGER_DB_PWD"
}

// The init{} scope allows the specification of initialisation procedures (before the web server
// goes public). All the code specified within the init{} scope is executed only once, when
// the service is started.
init
{
    println@Console( "initialising logger")();

    // contact consul kv for data
    entry.key = dbHost;
    get@Consul(entry)(loggerDBHost);
    entry.key = dbName;
    get@Consul(entry)(loggerDBName);
    entry.key = dbUser;
    get@Consul(entry)(loggerDBUsername);
    entry.key = dbPwd;
    get@Consul(entry)(loggerDBPassword);
    entry.key = dbPort;
    get@Consul(entry)(loggerDBPort);

    // configure & connect
    with ( connectionInfo ) {
        .driver = "postgresql";
        .host = loggerDBHost.val;
        .port = int(loggerDBPort.val);
        .database = loggerDBName.val;
        .username = loggerDBUsername.val;
        .password = loggerDBPassword.val
    };
    connect@Database( connectionInfo )(void);

    // create table if it does not exist
    scope ( createTable ) {
        install ( SQLException => println@Console("log table already exists")() );
        updateRequest =
            "CREATE TABLE log(" +
            "  id SERIAL," + // PostgreSQL syntax for auto increment
            "  service VARCHAR(50) NOT NULL," +
            "  info TEXT NOT NULL," +
            "  level INTEGER," +
            "  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP," +
            "  PRIMARY KEY(id)" +
            ")";
        update@Database( updateRequest )( ret )
    };

    println@Console("initialised")()
}

// incomming requests
main
{
    [ health() ( resp ) {
        resp = "Service alive and reachable"
    }]

    [ about()( resp ) {
        resp = "
            The service logger was created at 2018-12-16 17:13:49.238752618 +0000 UTC m=+24.385533559 by Anders Fylling.
            The source code can be found at https://github.com/dm848/srv-logger
            While other services in the cluster (in the same namespace) can access it using the DNS name logger.
            Remember to specify the cluster namespace, if you are in a different namespace: logger.default

            Service Description
            The service for logging all actions within the system. It supplies a basic getter/setter interface which stores and retrieves content from a database
        "
    }]

    [ set( req )( res ) {
        insertReq = "INSERT INTO log(service, info, level) VALUES(:srv, :info, :lvl) RETURNING id";
        insertReq.srv = req.service;
        insertReq.info = req.info;
        insertReq.lvl = int(req.level);

        query@Database( insertReq )(sqlResponse);
        if (#sqlResponse.row == 1 && is_defined(sqlResponse.row[0].id)) {
            res = sqlResponse.row[0].id
        } else {
            res = -1
        }
    } ]

    [ get(req)(res) {
        q = "SELECT * FROM log";

        // service and id filter
        if (is_defined(req.id) || is_defined(req.service)) {
            q = q + " WHERE";
            if (is_defined(req.id)) {
                q = q + " id = :id";
                q.id = req.id
            };

            if (is_defined(req.service)) {
                if (is_defined(req.id)) {
                    q = q + " AND"
                };
                q = q + " service = :service";
                q.service = req.service
            }
        };

        // before and after timestamp filters
        // TODO

        // limit number of rows
        if (is_defined(req.limit) && req.limit > 0) {
            q = q + " LIMIT :limit";
            q.limit = req.limit
        };


        query@Database(q)(sqlResponse);
        res.values -> sqlResponse.row
    } ]
}

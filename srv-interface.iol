type LogEntry:void {
    .service: string // name of service inserting the log
    .info: string // what happened?
    .level: int // log level, info, debug, etc. use java log level
}

type Query:void {
  .id?: int
  .before?: string // TODO
  .after?: string // TODO
  .limit?: int
  .service?: string
}

interface LoggerInterface {
  RequestResponse:
    about(void)(string)
    get(Query)(undefined), // list
    set(LogEntry)(int) // returns entry id, otherwise -1
}
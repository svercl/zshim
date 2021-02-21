pub const BOOL = c_int;
pub const FALSE = 0;
pub const TRUE = 1;
pub const DWORD = c_ulong;
pub const PHANDLER_ROUTINE = ?fn (DWORD) callconv(.C) BOOL;
pub const CTRL_C_EVENT = 0;
pub const CTRL_BREAK_EVENT = 1;
pub const CTRL_CLOSE_EVENT = 2;
pub const CTRL_LOGOFF_EVENT = 5;
pub const CTRL_SHUTDOWN_EVENT = 6;

pub extern fn SetConsoleCtrlHandler(HandlerRoutine: PHANDLER_ROUTINE, Add: BOOL) BOOL;

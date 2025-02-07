-- Rioni's Silent command executioner
--
-- Copyright (c) 2024 Nicolas Rosa
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.

local ffi = require("ffi")
---@diagnostic disable: undefined-field

ffi.cdef [[
typedef int BOOL;
typedef unsigned long DWORD;
typedef const char* LPCSTR;
typedef void* HANDLE;
typedef unsigned short WORD;

typedef struct {
    DWORD cb;
    LPCSTR lpReserved;
    LPCSTR lpDesktop;
    LPCSTR lpTitle;
    DWORD dwX;
    DWORD dwY;
    DWORD dwXSize;
    DWORD dwYSize;
    DWORD dwXCountChars;
    DWORD dwYCountChars;
    DWORD dwFillAttribute;
    DWORD dwFlags;
    WORD  wShowWindow;
    WORD  cbReserved2;
    char* lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
} STARTUPINFOA;

typedef struct {
    HANDLE hProcess;
    HANDLE hThread;
    DWORD  dwProcessId;
    DWORD  dwThreadId;
} PROCESS_INFORMATION;

BOOL CreateProcessA(
    LPCSTR lpApplicationName,
    LPCSTR lpCommandLine,
    void* lpProcessAttributes,
    void* lpThreadAttributes,
    BOOL bInheritHandles,
    DWORD dwCreationFlags,
    void* lpEnvironment,
    LPCSTR lpCurrentDirectory,
    STARTUPINFOA* lpStartupInfo,
    PROCESS_INFORMATION* lpProcessInformation
);

DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
BOOL CloseHandle(HANDLE hObject);
DWORD GetExitCodeProcess(HANDLE hProcess, DWORD* lpExitCode);
HANDLE GetStdHandle(DWORD nStdHandle);

static const DWORD INFINITE = 0xFFFFFFFF;
static const DWORD CREATE_NO_WINDOW = 0x08000000;
]]

local kernel32 = ffi.load("kernel32")

--- Executes a command silently and returns its output as a string.
---@param command string Command to execute
---@return boolean success, string result Command output.
local function execute_silent_command(command)
    local startup_info = ffi.new("STARTUPINFOA")
    local process_info = ffi.new("PROCESS_INFORMATION")
    startup_info.cb = ffi.sizeof(startup_info) ---@diagnostic disable-line

    -- To get the result we need to use a temporary file, sadly
    local temp_file = os.getenv("TEMP") .. "\\output.txt"
    local cmd = 'cmd.exe /C "' .. command .. ' > ' .. temp_file .. ' 2>&1"'

    local success = kernel32.CreateProcessA(
        nil,                    -- Executable name (not needed here)
        cmd,                    -- Command line
        nil,                    -- No custom security
        nil,                    -- No custom security
        false,                  -- Do not inherit handles
        ffi.C.CREATE_NO_WINDOW, -- Do not create window
        nil,                    -- Inherit environment variables
        nil,                    -- Current working directory
        startup_info,
        process_info
    )

    if success == 0 then
        error("Error executing the command. Error code: " .. tonumber(ffi.C.GetLastError()))
    end

    -- Wait for the process to finish
    kernel32.WaitForSingleObject(process_info.hProcess, ffi.C.INFINITE)

    -- Error checking
    local exit_code = ffi.new("DWORD[1]")
    kernel32.GetExitCodeProcess(process_info.hProcess, exit_code)
    local error = ""
    local success = true

    if exit_code[0] ~= 0 then
        success = false
        error = "Command failed with exit code " .. exit_code[0]
    end

    -- Read the temporary file with the command output
    local file = io.open(temp_file, "r")

    if not file then
        error("Error reading the output file") -- This should never happen
    end

    local result = file:read("*a")
    file:close()

    -- Clean up resources and close handles
    kernel32.CloseHandle(process_info.hProcess)
    kernel32.CloseHandle(process_info.hThread)

    if not success then
        return success, error .. ": " .. result
    end

    return success, result
end
return execute_silent_command
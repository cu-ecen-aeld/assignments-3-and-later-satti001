#include "systemcalls.h"
#include <sys/wait.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{

/*
 * TODO  add your code here
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/
    int return_val = system(cmd);

    // Return a boolean true if the system() call completed with success
    if (return_val == 0) {
        return true;
    }
    // or false() if it returned a failure
    else {
        return false;
    }
    //return true;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];

/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/
    // Create a child process
    pid_t child_pid = fork();

    if (child_pid == -1) {
        // Failed to create child process
        return false;
    } else if (child_pid == 0) {
        // This is the child process

        // Execute the command with execv
        if (execv(command[0], command) == -1) {
            // Failed to execute command
            exit(EXIT_FAILURE);
        }
    } else {
        // This is the parent process

        // Wait for the child process to complete
        int status;
        if (waitpid(child_pid, &status, 0) == -1) {
            // Failed to wait for child process
            return false;
        } else if (WIFEXITED(status)) {
            // Child process exited normally
            int exit_status = WEXITSTATUS(status);
            if (exit_status == 0) {
                // Command executed successfully
                return true;
            } else {
                // Command returned non-zero exit status
                return false;
            }
        } else {
            // Child process terminated abnormally
            return false;
        }
    }
    va_end(args);

    return true;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];


/*
 * TODO
 *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
 *   redirect standard out to a file specified by outputfile.
 *   The rest of the behaviour is same as do_exec()
 *
*/
    int saved_stdout = dup(STDOUT_FILENO); // Step 1

    int output_fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR); // Step 2

    if (output_fd == -1) {
        perror("open");
        return false;
    }

    if (dup2(output_fd, STDOUT_FILENO) == -1) { // Step 3
        perror("dup2");
        return false;
    }

    pid_t pid = fork();

    if (pid == -1) {
        perror("fork");
        return false;
    } else if (pid == 0) { // child process
        execv(command[0], command); // Step 4
        perror("execv");
        exit(EXIT_FAILURE);
    } else { // parent process
        int status;
        if (waitpid(pid, &status, 0) == -1) {
            perror("waitpid");
            return false;
        }
    }

    if (dup2(saved_stdout, STDOUT_FILENO) == -1) { // Step 5
        perror("dup2");
        return false;
    }

    close(output_fd); // Step 6
    va_end(args);

    return true;
}

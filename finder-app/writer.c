#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

#define RED     "\x1b[31m"
#define RESET   "\x1b[0m"

void log_error(const char *msg) {
    fprintf(stderr, RED "%s\n" RESET, msg);
    syslog(LOG_ERR, "%s", msg);
}

void log_info(const char *msg) {
    syslog(LOG_INFO, "%s", msg);
}

int main(int argc, char *argv[]) {
    openlog(NULL, 0, LOG_USER);

    if (argc != 3) {
        log_error("USAGE: ./writer filename str");
        log_error("Invalid number of arguments");
        return EXIT_FAILURE;
    }

    const char *filename = argv[1];
    const char *str = argv[2];

    FILE *file = fopen(filename, "w");
    if (file == NULL) {
        char *msg = malloc(strlen(filename) + 30);
        sprintf(msg, "Failed to open file %s", filename);
        log_error(msg);
        free(msg);
        return EXIT_FAILURE;
    }

    log_info("File opened successfully");

    size_t bytes_written = fwrite(str, sizeof(char), strlen(str), file);
    if (bytes_written != strlen(str)) {
        char *msg = malloc(strlen(filename) + 40);
        sprintf(msg, "Failed to write to file %s", filename);
        log_error(msg);
        free(msg);
        fclose(file);
        return EXIT_FAILURE;
    }

    fclose(file);
    log_info("File closed successfully");

    return EXIT_SUCCESS;
}

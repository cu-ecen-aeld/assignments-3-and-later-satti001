CROSS_COMPILE=
CC=$(CROSS_COMPILE)gcc
RM=rm -rf

all: writer

%:%.c
	$(CC) $< -o $@
clean:
	$(RM) *.o writer

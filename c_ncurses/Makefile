# Makefile

CC = gcc
CFLAGS = -lncurses -Wall -Wextra -pedantic -std=c99
TARGET = result.out
SRC = blck.c

# make
all: $(TARGET)

# make blck
$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

# make run
run: $(TARGET)
	./$(TARGET)

# make clean
clean:
	rm -f $(TARGET)

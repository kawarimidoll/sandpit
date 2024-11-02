#include <ncurses.h>

int main(void) {
  initscr();

  // hide key inputs
  noecho();

  // hide cursor
  curs_set(0);

  mvprintw(12, 30, "Hello World!");
  mvprintw(13, 30, "Press 'q' to exit.");

  while (true) {
    int ch = getch();
    if (ch == 'q')
      break;
  }
  endwin();
}

#include <ncurses.h>

int main(void) {
  initscr();

  // hide key inputs
  noecho();

  // hide cursor
  curs_set(0);

  // enable mouse event detection
  keypad(stdscr, TRUE);
  mousemask(REPORT_MOUSE_POSITION, NULL);

  MEVENT e;
  int px = 2;

  mvprintw(12, 30, "Hello World!");
  mvprintw(13, 30, "Press 'q' to exit.");

  while (true) {
    int ch = getch();
    if (ch == 'q') {
      break;
    }

    if (ch == KEY_MOUSE) {
      if (getmouse(&e) == OK) {
        clear();
        px = e.x;
        if (px < 2) {
          px = 2;
        }
        if (px > 77) {
          px = 77;
        }
        mvprintw(23, px - 2, "=====");
        refresh();
      }
    }
  }
  endwin();
}

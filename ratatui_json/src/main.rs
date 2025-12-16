use ratatui::Terminal;
use ratatui::backend::Backend;
use ratatui::backend::CrosstermBackend;
use ratatui::crossterm::event::DisableMouseCapture;
use ratatui::crossterm::event::EnableMouseCapture;
use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{EnterAlternateScreen, enable_raw_mode};
use ratatui::crossterm::terminal::{LeaveAlternateScreen, disable_raw_mode};
use std::error::Error;
use std::io;

// import modules to enable rust-analyzer for now
mod app;
use crate::app::App;

fn main() -> Result<(), Box<dyn Error>> {
    // --- setup terminal ---
    enable_raw_mode()?;

    // This is a special case. Normally using stdout is fine
    // We want to use this program like `ratatui_json > output.json`.
    // To do this, we render output to `stderr` and print out completed json to `stdout`.
    let mut stderr = io::stderr();

    execute!(stderr, EnterAlternateScreen, EnableMouseCapture)?;

    // --- create state ---

    let backend = CrosstermBackend::new(stderr);
    let mut terminal = Terminal::new(backend)?;

    // --- create app and run it ---

    let mut app = App::new();
    let res = run_app(&mut terminal, &mut app);

    // --- restore terminal ---
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    // not to remove our message, we should call print function after
    // execute!(LeaveAlternateScreen)

    // check if run_app function errored
    if let Ok(do_print) = res {
        if do_print {
            app.print_json()?;
        }
    } else if let Err(err) = res {
        println!("{err:?}");
    }

    Ok(())
}

fn run_app<B: Backend>(_terminal: &mut Terminal<B>, _app: &mut App) -> io::Result<bool> {
    todo!()
}

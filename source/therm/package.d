module therm;

import therm.os_core;

struct Therm {
    import std.conv : text;
    import std.format : format;

    this(OsCore core)
    in (core !is null)
    {
        this.core = core;
    }

    static Therm create() {
        version (Windows) {
            import therm.windows;
            return Therm(new WindowsCore());
        } else version (Posix) {
            import therm.posix;
            return Therm(new PosixCore());
        } else {
            static assert(false, "OS not supported");
        }
    }

    void write(T...)(T args) {
        core.write(text(args));
    }

    void writeln(T...)(T args) {
        write(args, '\n');
    }

    void writef(alias fmt, T...)(T args) {
        core.write(format!fmt(args));
    }

    void writefln(alias fmt, T...)(T args) {
        writef!(fmt ~ "\n")(args);
    }

    void ewrite(T...)(T args) {
        core.ewrite(text(args));
    }

    void ewriteln(T...)(T args) {
        ewrite(args, '\n');
    }

    void ewritef(alias fmt, T...)(T args) {
        core.ewrite(format!fmt(args));
    }

    void ewritefln(alias fmt, T...)(T args) {
        ewritef!(fmt ~ "\n")(args);
    }

    string readln(in string prompt) {
        core.write(prompt);
        core.flush();

        editor.prompt = prompt;

        auto vt = Vt.createInactive();
        loop: foreach (c; &core.read) {
            if (vt.active) {
                AnsiInputEscape escape;
                if (vt.handle(c, &escape)) {
                    final switch (escape) with (AnsiInputEscape) {
                        case Unknown: break;

                        case ArrowUp: editor.arrowUp(); break;
                        case ArrowDown: editor.arrowDown(); break;
                        case ArrowLeft: editor.arrowLeft(); break;
                        case ArrowRight: editor.arrowRight(); break;
                        case Home: editor.home(); break;
                        case End: editor.end(); break;
                    }
                } else {
                    continue;
                }
            } else {
                switch (c) {
                    case '\r':
                    case '\n':
                        break loop;

                    case '\x7F':
                        editor.backspace();
                        break;

                    case '\x1B':
                        vt = Vt();
                        continue loop;

                    default:
                        editor.type(c);
                        break;
                }
            }

            write(
                Vt.refreshLine(),
                prompt,
                editor.line,
                Vt.cursorTo(editor.cursor).expand
            );
            core.flush();
        }

        core.write("\n");
        core.flush();

        return editor.commit();
    }

    private OsCore core;
    private LineEditor editor;
}

private struct LineEditor {
    import std.array : insertInPlace, replaceInPlace;
    import std.utf : count, toUTF8;
    import core.internal.utf;

    dstring buffer;
    short cursor = 1;
    short minCursor = 1;

    dstring[] history = [];
    size_t historyAt = 0;

    invariant(cursor >= 1);
    invariant(minCursor <= cursor);
    invariant(historyAt <= history.length);

    string commit() {
        auto s = line.toUTF8();

        history ~= line;
        historyAt = history.length;
        buffer = ""d;

        return s;
    }

    void type(in dchar c) {
        if (!isLatest) {
            buffer = history[historyAt].dup;
            historyAt = history.length;
        }

        buffer.insertInPlace(cursorIndex, c);
        ++cursor;
    }

    void backspace() {
        if (line.length == 0) return;

        if (!isLatest) {
            buffer = history[historyAt].dup;
            historyAt = history.length;
        }

        buffer.replaceInPlace(cursorIndex - 1, cursorIndex, cast(char[]) []);
        --cursor;
    }

    /// Go to the past in history
    void arrowUp() {
        if (historyAt > 0) {
            --historyAt;
            cursor = maxCursor;
        }
    }

    /// Go to the future in history
    void arrowDown() {
        if (historyAt < history.length) {
            ++historyAt;
            cursor = maxCursor;
        }
    }

    void arrowRight() {
        if (cursor < maxCursor) {
            ++cursor;
        }
    }

    void arrowLeft() {
        if (cursor > minCursor) {
            --cursor;
        }
    }

    void home() {
        cursor = minCursor;
    }

    void end() {
        cursor = maxCursor;
    }

    short cursorIndex() const {
        return cast(short) (cursor - minCursor);
    }

    short maxCursor() const {
        return cast(short) (minCursor + line.length);
    }

    bool isLatest() const => historyAt == history.length;

    dstring line() const => isLatest ? buffer : history[historyAt];

    void prompt(in string p) {
        cursor = minCursor = cast(short) (1 + p.count);
    }
}

private enum AnsiInputEscape {
    Unknown,

    ArrowUp,
    ArrowDown,
    ArrowRight,
    ArrowLeft,
    Home,
    End,
}

private struct Vt {
    bool active = true;
    bool gotStart = false;

    static Vt createInactive() {
        return Vt(active: false);
    }

    bool handle(dchar c, scope AnsiInputEscape* escape)
    in (active)
    {
        if (!gotStart) {
            if (c == '[' || c == 'O') {
                gotStart = true;
            } else {
                active = false;
            }

            return false;
        }

        active = false;
        switch (c) with (AnsiInputEscape) {
            case 'A':*escape = ArrowUp; return true;
            case 'B': *escape = ArrowDown; return true;
            case 'C': *escape = ArrowRight; return true;
            case 'D': *escape = ArrowLeft; return true;
            case 'H': *escape = Home; return true;
            case 'F': *escape = End; return true;

            default: *escape = Unknown; return true;
        }
    }

    static string refreshLine() {
        return "\r\x1B[0K";
    }

    static auto cursorTo(in short n) {
        import std.typecons : tuple;
        return tuple("\x1B[", n, 'G');
    }
}

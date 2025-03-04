module therm;

import therm.os_core;

struct Therm {
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
            static assert(false, "todo: not implemented");
        } else {
            static assert(false, "OS not supported");
        }
    }

    void write(T...)(T args) {
        import std.conv : text;
        core.write(text(args));
    }

    void writeln(T...)(T args) {
        write(args, '\n');
    }

    void writef(alias fmt, T...)(T args) {
        import std.format : format;
        core.write(format!fmt(args));
    }

    void writefln(alias fmt, T...)(T args) {
        writef!(fmt ~ "\n")(args);
    }

    string readln(in string prompt) {
        core.write(prompt);
        core.flush();

        auto editor = LineEditor(prompt);
        auto vt = Vt.createInactive();

        loop: foreach (c; &core.read) {
            if (vt.active) {
                AnsiInputEscape escape;
                if (vt.handle(c, &escape)) {
                    final switch (escape) with (AnsiInputEscape) {
                        case Unknown: break;

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

        return editor.finish();
    }

    private OsCore core;
}


private struct LineEditor {
    import std.array : insertInPlace, replaceInPlace;
    import std.utf : count, toUTF8;

    dstring line;
    short cursor;

    immutable short minCursor;

    this(in string prompt) {
        cursor = minCursor = cast(short) (1 + prompt.count);
    }

    invariant(cursor >= 1);

    string finish() const {
        return line.toUTF8();
    }

    void type(in dchar c) {
        line.insertInPlace(cursorIndex, c);
        ++cursor;
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

    void backspace() {
        if (line.length == 0) return;

        line.replaceInPlace(cursorIndex - 1, cursorIndex, cast(char[]) []);
        --cursor;
    }

    short cursorIndex() const {
        return cast(short) (cursor - minCursor);
    }

    short maxCursor() const {
        return cast(short) (minCursor + line.length);
    }
}

private enum AnsiInputEscape {
    Unknown,

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

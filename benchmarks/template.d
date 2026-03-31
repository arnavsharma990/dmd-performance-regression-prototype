import std.stdio;
import std.traits;
import std.meta;
import std.typecons;

// A recursive template that computes a Fibonacci-like value at compile time
// to create non-trivial template instantiation load.
template Fib(int N)
{
    static if (N <= 1)
        enum Fib = N;
    else
        enum Fib = Fib!(N - 1) + Fib!(N - 2);
}

// A simple generic container to stress type-parameterised code
struct Box(T)
{
    T value;

    this(T v) { value = v; }

    T get() const { return value; }

    Box!T map(alias fn)() const
    {
        return Box!T(fn(value));
    }
}

// Expand a list of types and check basic traits for each
template CheckTypes(Types...)
{
    static foreach (T; Types)
    {
        static assert(is(T), "Type must be valid: " ~ T.stringof);
    }
    enum CheckTypes = true;
}

// Instantiate CheckTypes with a variety of built-in types
static assert(CheckTypes!(int, float, double, char, bool, long, uint, ubyte));

void main()
{
    // Print a few compile-time Fibonacci values to verify template expansion
    writeln("Fib(0)  = ", Fib!0);
    writeln("Fib(5)  = ", Fib!5);
    writeln("Fib(10) = ", Fib!10);
    writeln("Fib(15) = ", Fib!15);
    writeln("Fib(20) = ", Fib!20);

    // Exercise the generic Box with several types
    auto bi = Box!int(42);
    auto bf = Box!double(3.14);
    auto bs = Box!string("template");

    writeln("Box!int    : ", bi.get());
    writeln("Box!double : ", bf.get());
    writeln("Box!string : ", bs.get());

    // Use Nullable (from std.typecons) to add more template instantiations
    Nullable!int ni = 7;
    Nullable!double nd = 2.71;
    writeln("Nullable!int    : ", ni.get());
    writeln("Nullable!double : ", nd.get());
}

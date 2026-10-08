using System;
using EasyEDA_Loader;

int checks = 0;
void Check(bool condition, string message)
{
    checks++;
    if (!condition) throw new Exception("FAILED: " + message);
}

void ValidateSide(double body, int pins)
{
    if (pins == 0) return;
    double start = SymbolLayoutGeometry.CenterPinStart(body, pins);
    double end = start + (pins - 1) * SymbolLayoutGeometry.PinGridMils;
    Check(start >= SymbolLayoutGeometry.PinGridMils, "start margin");
    Check(end <= body - SymbolLayoutGeometry.PinGridMils, "end margin");
    for (int i = 0; i < pins; i++)
    {
        double location = start + i * SymbolLayoutGeometry.PinGridMils;
        Check(location % SymbolLayoutGeometry.PinGridMils == 0, "grid location");
    }
}

var rp2040 = SymbolLayoutGeometry.BodySize(700, 900, 14, 14);
Check(rp2040.Width == 1500 && rp2040.Height == 1500, "compact 14 pins/side");
Check(rp2040.Width < 2300, "smaller than legacy 8x100 mil margins");
ValidateSide(rp2040.Width, 14);
ValidateSide(rp2040.Height, 14);

var largeSource = SymbolLayoutGeometry.BodySize(1700, 1100, 4, 4);
Check(largeSource.Width == 1700 && largeSource.Height == 1100, "preserve larger source body");
ValidateSide(largeSource.Width, 4);
ValidateSide(largeSource.Height, 4);

var small = SymbolLayoutGeometry.BodySize(0, 0, 1, 1);
Check(small.Width == 300 && small.Height == 300, "minimum body for two-side device");
ValidateSide(small.Width, 1);
ValidateSide(small.Height, 1);

var dense = SymbolLayoutGeometry.BodySize(300, 300, 50, 12);
Check(dense.Width == 5100 && dense.Height == 1300, "dense pin sides enlarge to fit");
ValidateSide(dense.Width, 50);
ValidateSide(dense.Height, 12);

for (int n = 1; n <= 128; n++)
{
    var b = SymbolLayoutGeometry.BodySize(0, 0, n, n);
    ValidateSide(b.Width, n);
    ValidateSide(b.Height, n);
}
Check(SymbolLayoutGeometry.PinLengthMils % SymbolLayoutGeometry.PinGridMils == 0,
    "outer pin connection length on 100 mil grid");

Console.WriteLine($"PASS: {checks} symbol geometry assertions, including 128 pin-density cases.");

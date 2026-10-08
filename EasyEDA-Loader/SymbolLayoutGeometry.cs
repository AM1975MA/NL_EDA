using System;

namespace EasyEDA_Loader
{
    /// <summary>
    /// Pure symbol geometry calculations: mil units and 100 mil snap grid.
    /// Kept independent of Altium/DevExpress to support local unit testing.
    /// </summary>
    public static class SymbolLayoutGeometry
    {
        public const int PinGridMils = 100;
        public const int PinLengthMils = 100;
        public const int MinimumBodyMils = 300;
        public const int EdgePinMarginGrids = 1;
        public const double EasyEdaUnitMils = 10.0;

        public static double RoundUpToGrid(double value)
        {
            if (double.IsNaN(value) || double.IsInfinity(value) || value < 0)
                throw new ArgumentOutOfRangeException(nameof(value));
            return Math.Ceiling(value / PinGridMils) * PinGridMils;
        }

        public static double CenterPinStart(double bodyLength, int count)
        {
            if (bodyLength < 0 || count < 0)
                throw new ArgumentOutOfRangeException(nameof(count));
            if (count == 0)
                return 0;

            double span = (count - 1) * PinGridMils;
            if (span + 2 * PinGridMils > bodyLength)
                throw new ArgumentException("Not enough body size to fit a grid-safe pin row.");

            return Math.Floor((bodyLength - span) / (2.0 * PinGridMils)) * PinGridMils;
        }

        public static (double Width, double Height) BodySize(
            double sourceWidthMils, double sourceHeightMils,
            int horizontalPins, int verticalPins)
        {
            if (horizontalPins < 0 || verticalPins < 0)
                throw new ArgumentOutOfRangeException(nameof(horizontalPins));

            // Enough room for 100 mil between adjacent pins, plus one 100 mil
            // clearance unit from each end of the body.
            double minimumWidthForPins = horizontalPins == 0 ? 0 :
                (horizontalPins - 1 + 2 * EdgePinMarginGrids) * PinGridMils;
            double minimumHeightForPins = verticalPins == 0 ? 0 :
                (verticalPins - 1 + 2 * EdgePinMarginGrids) * PinGridMils;

            return (
                RoundUpToGrid(Math.Max(MinimumBodyMils, Math.Max(sourceWidthMils, minimumWidthForPins))),
                RoundUpToGrid(Math.Max(MinimumBodyMils, Math.Max(sourceHeightMils, minimumHeightForPins)))
            );
        }
    }
}

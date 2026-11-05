using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Oscilloscope
{
    public class ConfigPrama
    {
        public const byte FrameHeader = 0x5A; //frame header
        public const byte FrameTail = 0x5B; //frame tail
        public const int FrameLength = 8; //frame length

    }
}

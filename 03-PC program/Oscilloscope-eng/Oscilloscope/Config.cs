using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Oscilloscope
{
    public class ConfigPrama
    {
        public const byte FrameHeader = 0x5A; //帧头
        public const byte FrameTail = 0x5B; //帧尾
        public const int FrameLength = 8; //帧长

    }
}

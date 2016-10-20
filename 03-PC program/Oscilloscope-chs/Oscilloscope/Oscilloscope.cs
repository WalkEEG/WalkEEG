using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Threading;
using System.Text;
using System.Windows.Forms;
using System.IO.Ports;
using System.Windows.Forms.DataVisualization.Charting;

namespace Oscilloscope
{
    public partial class Oscilloscope : Form
    {
        #region 变量定义

        public Int32 recFrameNum = 0; //接收到的数据帧数
        public Int32 recByteNum = 0;  //接收到的数据字节数
        private List<byte> recBuffer = new List<byte>();
        private bool handerListening = false;
        private bool comClosing = false;
        private int pointIndex = 0;
        private bool axisChange = false;
        public bool Isput = false;
        public byte[] buf;
        #endregion

        public Oscilloscope()
        {
            InitializeComponent();

        }

        #region 串口初始化
        private void buttonSwitch_Click(object sender, EventArgs e)
        {
            try
            {
                if (serialPort1.IsOpen)
                {
                    comClosing = true;//串口关闭动作正在进行
                   while (handerListening) Application.DoEvents();//关闭串口前处理完消息队列中的所有事件

                    serialPort1.Close();
                    if (!serialPort1.IsOpen)
                    {
                        buttonSwitch.Text = "打开串口";
                        labelStatus.ForeColor = Color.Black;
                    }
                }
                else
                {
                    comClosing = false;
                    serialPort1.PortName = comboBoxPort.Text;
                    serialPort1.BaudRate = Convert.ToInt32(comboBoxBaudRate.Text);
                    serialPort1.DataBits = Convert.ToInt32(comboBoxData.Text);
                    switch (comboBoxCheck.Text)
                    {
                        case "None": serialPort1.Parity = System.IO.Ports.Parity.None; break;
                        case "Odd": serialPort1.Parity = System.IO.Ports.Parity.Odd; break;
                        case "Even": serialPort1.Parity = System.IO.Ports.Parity.Even; break;
                        case "Mark": serialPort1.Parity = System.IO.Ports.Parity.Mark; break;
                        case "Space": serialPort1.Parity = System.IO.Ports.Parity.Space; break;
                        default: break;
                    }
                    serialPort1.StopBits = (System.IO.Ports.StopBits)Convert.ToInt32(comboBoxStopBit.Text);

                    try
                    {
                        serialPort1.Open();
                    }
                    catch(Exception ex)
                    {
                        //现实异常信息给客户。
                        MessageBox.Show(ex.Message);
                        //捕获到异常信息，创建一个新的comm对象，之前的不能用了。
                        //serialPort1 = new SerialPort();
                    }

                    if (serialPort1.IsOpen)
                    {
                        buttonSwitch.Text = "关闭串口";
                        labelStatus.ForeColor = Color.Red;
                    }
                }
            }
            catch (Exception err)
            {
                MessageBox.Show(err.Message);
            }
        }
        #endregion


        #region 串口接收  

        private void serialPort1_DataReceived(object sender, System.IO.Ports.SerialDataReceivedEventArgs e)
        {

                double xValue;
                double yValue = 0;
                double zValue = 0;
                byte[] xVarry = new byte[2];
                byte[] yVarry = new byte[2];
                byte[] zVarry = new byte[2];

    
            
            if (comClosing == true) return; //如果正在关闭，忽略操作，直接返回，尽快的完成串口监听线程的一次循环
            try
            {
                handerListening = true;//设置标记，说明已经开始处理数据，一会儿要使用系统UI的。

                int n = serialPort1.BytesToRead;
                byte[] buf = new byte[n];

                recFrameNum++;
                recByteNum += n;
                serialPort1.Read(buf, 0, n);
                recBuffer.AddRange(buf);

                //对接收到的数据进行显示         
                this.BeginInvoke((EventHandler)(delegate
                {
                    labelRecByteCount.Text = Convert.ToString(recByteNum);
                    labelRecFrameCount.Text = Convert.ToString(recFrameNum);
                    //if (checkBoxRecDisplay.Checked == true)
                    //{
                    //    foreach (var temp in buf) { richTextBox1.Text += temp.ToString("X2") + " "; }
                    //    richTextBox1.AppendText("\r\n");
                    //    this.richTextBox1.ScrollToCaret();
                    //}
                }));
                
                if(buf.Length >= 8)
                {
                    if (buf[0] == ConfigPrama.FrameHeader && buf[7] == ConfigPrama.FrameTail)
                    {
                        //通道一
                        xVarry[1] = buf[1];
                        xVarry[0] = buf[2];
                        xValue = Convert.ToDouble(BitConverter.ToInt16( xVarry,0));
                        xValue = xValue * 3.6 / 1024;
                        //通道二
                        yVarry[1] = buf[3];
                        yVarry[0] = buf[4];
                        yValue = Convert.ToDouble(BitConverter.ToInt16(yVarry, 0));
                        yValue = yValue * 3.6 / 1024;
                        //通道三
                        zVarry[1] = buf[5];
                        zVarry[0] = buf[6];
                        zValue = Convert.ToDouble(BitConverter.ToInt16(zVarry, 0));
                        zValue = zValue * 3.6 / 1024;
                        this.BeginInvoke((EventHandler)(delegate { paint_ax(xValue, yValue, zValue); }));
                    }
                }
                else
                {

                    
                }
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
            finally
            {
                handerListening = false;
            }
        }
        #endregion

        #region 数据缓冲清理
        public void Updatetextbox()
        {

        }
        #endregion

        #region 清空接收区和接收记录
        private void buttonClear_Click(object sender, EventArgs e)
        {

            recFrameNum = 0;
            recByteNum = 0;
            labelRecByteCount.Text = "0";
            labelRecFrameCount.Text = "0";
        }
        #endregion

        private void buttonSave_Click(object sender, EventArgs e)
        {

        }

        #region 绘图接口
        void paint_ax(double x,double y,double z)
        {
            // Define some variables
            int numberOfPointsInChart = 100;

            try
            {
                chart1.ChartAreas["ChartArea1"].AxisX.Minimum = 0;
                chart1.ChartAreas["ChartArea1"].AxisX.Maximum = 100;
                chart1.ChartAreas["ChartArea1"].AxisY.Minimum = -1;
                chart1.ChartAreas["ChartArea1"].AxisY.Maximum = 4;
                chart1.ResetAutoValues();

                if (checkBox1.Checked == true)
                {
                            
                    chart1.Series["通道一"].Points.AddXY(pointIndex, x);
                }
                if (checkBox2.Checked == true)
                {
                    chart1.Series["通道二"].Points.AddXY(pointIndex, y);
                }
                if (checkBox3.Checked == true)
                {
                    chart1.Series["通道三"].Points.AddXY(pointIndex, z);
                }
                pointIndex++;


                if(chart1.Series[0].Points.Count > numberOfPointsInChart)
                {
                    axisChange = true;

                }
                   // Adjust X axis scale
                if(axisChange)
                {
                    chart1.ChartAreas["ChartArea1"].AxisX.Minimum = pointIndex + 1 - numberOfPointsInChart;
                    chart1.ChartAreas["ChartArea1"].AxisX.Maximum = chart1.ChartAreas["ChartArea1"].AxisX.Minimum + numberOfPointsInChart;
                }


                // Invalidate chart
                chart1.Invalidate();

            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }


        }
        #endregion

        #region 清除绘图
        private void buttonGclear_Click(object sender, EventArgs e)
        {
            chart1.Series["通道一"].Points.Clear();
            chart1.Series["通道二"].Points.Clear();
            chart1.Series["通道三"].Points.Clear();
            pointIndex = 0;
            axisChange = false;
        }
        #endregion

 


    }
}

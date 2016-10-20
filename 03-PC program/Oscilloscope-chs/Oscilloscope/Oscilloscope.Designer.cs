namespace Oscilloscope
{
    partial class Oscilloscope
    {
        /// <summary>
        /// 必需的设计器变量。
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 清理所有正在使用的资源。
        /// </summary>
        /// <param name="disposing">如果应释放托管资源，为 true；否则为 false。</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows 窗体设计器生成的代码

        /// <summary>
        /// 设计器支持所需的方法 - 不要
        /// 使用代码编辑器修改此方法的内容。
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.Windows.Forms.DataVisualization.Charting.ChartArea chartArea1 = new System.Windows.Forms.DataVisualization.Charting.ChartArea();
            System.Windows.Forms.DataVisualization.Charting.Legend legend1 = new System.Windows.Forms.DataVisualization.Charting.Legend();
            System.Windows.Forms.DataVisualization.Charting.Series series1 = new System.Windows.Forms.DataVisualization.Charting.Series();
            System.Windows.Forms.DataVisualization.Charting.Series series2 = new System.Windows.Forms.DataVisualization.Charting.Series();
            System.Windows.Forms.DataVisualization.Charting.Series series3 = new System.Windows.Forms.DataVisualization.Charting.Series();
            System.Windows.Forms.DataVisualization.Charting.Title title1 = new System.Windows.Forms.DataVisualization.Charting.Title();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Oscilloscope));
            this.serialPort1 = new System.IO.Ports.SerialPort(this.components);
            this.groupBoxCom = new System.Windows.Forms.GroupBox();
            this.labelRecByteCount = new System.Windows.Forms.Label();
            this.buttonClear = new System.Windows.Forms.Button();
            this.label2 = new System.Windows.Forms.Label();
            this.labelRecFrameCount = new System.Windows.Forms.Label();
            this.labelRecFrameNum = new System.Windows.Forms.Label();
            this.labelStatus = new System.Windows.Forms.Label();
            this.comboBoxStopBit = new System.Windows.Forms.ComboBox();
            this.labelStopBit = new System.Windows.Forms.Label();
            this.comboBoxCheck = new System.Windows.Forms.ComboBox();
            this.labelCheck = new System.Windows.Forms.Label();
            this.comboBoxData = new System.Windows.Forms.ComboBox();
            this.labelData = new System.Windows.Forms.Label();
            this.comboBoxBaudRate = new System.Windows.Forms.ComboBox();
            this.labelBaudRate = new System.Windows.Forms.Label();
            this.comboBoxPort = new System.Windows.Forms.ComboBox();
            this.labelPort = new System.Windows.Forms.Label();
            this.buttonSwitch = new System.Windows.Forms.Button();
            this.groupBoxgraph = new System.Windows.Forms.GroupBox();
            this.button3 = new System.Windows.Forms.Button();
            this.button2 = new System.Windows.Forms.Button();
            this.button1 = new System.Windows.Forms.Button();
            this.buttonGclear = new System.Windows.Forms.Button();
            this.checkBox3 = new System.Windows.Forms.CheckBox();
            this.checkBox2 = new System.Windows.Forms.CheckBox();
            this.checkBox1 = new System.Windows.Forms.CheckBox();
            this.chart1 = new System.Windows.Forms.DataVisualization.Charting.Chart();
            this.groupBoxCom.SuspendLayout();
            this.groupBoxgraph.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.chart1)).BeginInit();
            this.SuspendLayout();
            // 
            // serialPort1
            // 
            this.serialPort1.BaudRate = 38400;
            this.serialPort1.PortName = "COM3";
            this.serialPort1.ReceivedBytesThreshold = 8;
            this.serialPort1.DataReceived += new System.IO.Ports.SerialDataReceivedEventHandler(this.serialPort1_DataReceived);
            // 
            // groupBoxCom
            // 
            this.groupBoxCom.Controls.Add(this.labelRecByteCount);
            this.groupBoxCom.Controls.Add(this.buttonClear);
            this.groupBoxCom.Controls.Add(this.label2);
            this.groupBoxCom.Controls.Add(this.labelRecFrameCount);
            this.groupBoxCom.Controls.Add(this.labelRecFrameNum);
            this.groupBoxCom.Controls.Add(this.labelStatus);
            this.groupBoxCom.Controls.Add(this.comboBoxStopBit);
            this.groupBoxCom.Controls.Add(this.labelStopBit);
            this.groupBoxCom.Controls.Add(this.comboBoxCheck);
            this.groupBoxCom.Controls.Add(this.labelCheck);
            this.groupBoxCom.Controls.Add(this.comboBoxData);
            this.groupBoxCom.Controls.Add(this.labelData);
            this.groupBoxCom.Controls.Add(this.comboBoxBaudRate);
            this.groupBoxCom.Controls.Add(this.labelBaudRate);
            this.groupBoxCom.Controls.Add(this.comboBoxPort);
            this.groupBoxCom.Controls.Add(this.labelPort);
            this.groupBoxCom.Controls.Add(this.buttonSwitch);
            this.groupBoxCom.Location = new System.Drawing.Point(16, 15);
            this.groupBoxCom.Margin = new System.Windows.Forms.Padding(4);
            this.groupBoxCom.Name = "groupBoxCom";
            this.groupBoxCom.Padding = new System.Windows.Forms.Padding(4);
            this.groupBoxCom.Size = new System.Drawing.Size(1288, 120);
            this.groupBoxCom.TabIndex = 0;
            this.groupBoxCom.TabStop = false;
            this.groupBoxCom.Text = "串口功能设置";
            // 
            // labelRecByteCount
            // 
            this.labelRecByteCount.Location = new System.Drawing.Point(736, 74);
            this.labelRecByteCount.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelRecByteCount.Name = "labelRecByteCount";
            this.labelRecByteCount.Size = new System.Drawing.Size(76, 29);
            this.labelRecByteCount.TabIndex = 15;
            this.labelRecByteCount.Text = "0";
            this.labelRecByteCount.TextAlign = System.Drawing.ContentAlignment.MiddleRight;
            // 
            // buttonClear
            // 
            this.buttonClear.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Left)));
            this.buttonClear.Location = new System.Drawing.Point(1056, 54);
            this.buttonClear.Margin = new System.Windows.Forms.Padding(4);
            this.buttonClear.Name = "buttonClear";
            this.buttonClear.Size = new System.Drawing.Size(118, 39);
            this.buttonClear.TabIndex = 4;
            this.buttonClear.Text = "清除数据";
            this.buttonClear.UseVisualStyleBackColor = true;
            this.buttonClear.Click += new System.EventHandler(this.buttonClear_Click);
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(657, 78);
            this.label2.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(82, 15);
            this.label2.TabIndex = 14;
            this.label2.Text = "收字节数：";
            // 
            // labelRecFrameCount
            // 
            this.labelRecFrameCount.Location = new System.Drawing.Point(736, 28);
            this.labelRecFrameCount.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelRecFrameCount.Name = "labelRecFrameCount";
            this.labelRecFrameCount.Size = new System.Drawing.Size(76, 29);
            this.labelRecFrameCount.TabIndex = 13;
            this.labelRecFrameCount.Text = "0";
            this.labelRecFrameCount.TextAlign = System.Drawing.ContentAlignment.MiddleRight;
            // 
            // labelRecFrameNum
            // 
            this.labelRecFrameNum.AutoSize = true;
            this.labelRecFrameNum.Location = new System.Drawing.Point(671, 34);
            this.labelRecFrameNum.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelRecFrameNum.Name = "labelRecFrameNum";
            this.labelRecFrameNum.Size = new System.Drawing.Size(67, 15);
            this.labelRecFrameNum.TabIndex = 12;
            this.labelRecFrameNum.Text = "收帧数：";
            // 
            // labelStatus
            // 
            this.labelStatus.AutoSize = true;
            this.labelStatus.Font = new System.Drawing.Font("宋体", 12F);
            this.labelStatus.Location = new System.Drawing.Point(456, 75);
            this.labelStatus.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelStatus.Name = "labelStatus";
            this.labelStatus.Size = new System.Drawing.Size(29, 20);
            this.labelStatus.TabIndex = 11;
            this.labelStatus.Text = "●";
            // 
            // comboBoxStopBit
            // 
            this.comboBoxStopBit.FormattingEnabled = true;
            this.comboBoxStopBit.Items.AddRange(new object[] {
            "1",
            "1.5",
            "2"});
            this.comboBoxStopBit.Location = new System.Drawing.Point(509, 29);
            this.comboBoxStopBit.Margin = new System.Windows.Forms.Padding(4);
            this.comboBoxStopBit.Name = "comboBoxStopBit";
            this.comboBoxStopBit.Size = new System.Drawing.Size(109, 23);
            this.comboBoxStopBit.TabIndex = 10;
            this.comboBoxStopBit.Text = "1";
            // 
            // labelStopBit
            // 
            this.labelStopBit.AutoSize = true;
            this.labelStopBit.Location = new System.Drawing.Point(444, 34);
            this.labelStopBit.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelStopBit.Name = "labelStopBit";
            this.labelStopBit.Size = new System.Drawing.Size(67, 15);
            this.labelStopBit.TabIndex = 9;
            this.labelStopBit.Text = "停止位：";
            // 
            // comboBoxCheck
            // 
            this.comboBoxCheck.FormattingEnabled = true;
            this.comboBoxCheck.Items.AddRange(new object[] {
            "None",
            "Odd",
            "Even",
            "Mark",
            "Space"});
            this.comboBoxCheck.Location = new System.Drawing.Point(297, 75);
            this.comboBoxCheck.Margin = new System.Windows.Forms.Padding(4);
            this.comboBoxCheck.Name = "comboBoxCheck";
            this.comboBoxCheck.Size = new System.Drawing.Size(109, 23);
            this.comboBoxCheck.TabIndex = 8;
            this.comboBoxCheck.Text = "None";
            // 
            // labelCheck
            // 
            this.labelCheck.AutoSize = true;
            this.labelCheck.Location = new System.Drawing.Point(229, 80);
            this.labelCheck.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelCheck.Name = "labelCheck";
            this.labelCheck.Size = new System.Drawing.Size(67, 15);
            this.labelCheck.TabIndex = 7;
            this.labelCheck.Text = "校验位：";
            // 
            // comboBoxData
            // 
            this.comboBoxData.FormattingEnabled = true;
            this.comboBoxData.Items.AddRange(new object[] {
            "6",
            "7",
            "8"});
            this.comboBoxData.Location = new System.Drawing.Point(297, 29);
            this.comboBoxData.Margin = new System.Windows.Forms.Padding(4);
            this.comboBoxData.Name = "comboBoxData";
            this.comboBoxData.Size = new System.Drawing.Size(109, 23);
            this.comboBoxData.TabIndex = 6;
            this.comboBoxData.Text = "8";
            // 
            // labelData
            // 
            this.labelData.AutoSize = true;
            this.labelData.Location = new System.Drawing.Point(229, 34);
            this.labelData.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelData.Name = "labelData";
            this.labelData.Size = new System.Drawing.Size(67, 15);
            this.labelData.TabIndex = 5;
            this.labelData.Text = "数据位：";
            // 
            // comboBoxBaudRate
            // 
            this.comboBoxBaudRate.FormattingEnabled = true;
            this.comboBoxBaudRate.Items.AddRange(new object[] {
            "1200",
            "2400",
            "4800",
            "9600",
            "19200",
            "38400",
            "115200"});
            this.comboBoxBaudRate.Location = new System.Drawing.Point(79, 75);
            this.comboBoxBaudRate.Margin = new System.Windows.Forms.Padding(4);
            this.comboBoxBaudRate.Name = "comboBoxBaudRate";
            this.comboBoxBaudRate.Size = new System.Drawing.Size(109, 23);
            this.comboBoxBaudRate.TabIndex = 4;
            this.comboBoxBaudRate.Text = "38400";
            // 
            // labelBaudRate
            // 
            this.labelBaudRate.AutoSize = true;
            this.labelBaudRate.Location = new System.Drawing.Point(11, 80);
            this.labelBaudRate.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelBaudRate.Name = "labelBaudRate";
            this.labelBaudRate.Size = new System.Drawing.Size(67, 15);
            this.labelBaudRate.TabIndex = 3;
            this.labelBaudRate.Text = "波特率：";
            // 
            // comboBoxPort
            // 
            this.comboBoxPort.FormattingEnabled = true;
            this.comboBoxPort.Items.AddRange(new object[] {
            "COM1",
            "COM2",
            "COM3",
            "COM4",
            "COM5",
            "COM6",
            "COM7",
            "COM8",
            "COM9",
            "COM10"});
            this.comboBoxPort.Location = new System.Drawing.Point(79, 29);
            this.comboBoxPort.Margin = new System.Windows.Forms.Padding(4);
            this.comboBoxPort.Name = "comboBoxPort";
            this.comboBoxPort.Size = new System.Drawing.Size(109, 23);
            this.comboBoxPort.TabIndex = 2;
            this.comboBoxPort.Text = "COM3";
            // 
            // labelPort
            // 
            this.labelPort.AutoSize = true;
            this.labelPort.Location = new System.Drawing.Point(11, 34);
            this.labelPort.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.labelPort.Name = "labelPort";
            this.labelPort.Size = new System.Drawing.Size(68, 15);
            this.labelPort.TabIndex = 1;
            this.labelPort.Text = "端  口：";
            // 
            // buttonSwitch
            // 
            this.buttonSwitch.Location = new System.Drawing.Point(509, 71);
            this.buttonSwitch.Margin = new System.Windows.Forms.Padding(4);
            this.buttonSwitch.Name = "buttonSwitch";
            this.buttonSwitch.Size = new System.Drawing.Size(100, 29);
            this.buttonSwitch.TabIndex = 0;
            this.buttonSwitch.Text = "打开串口";
            this.buttonSwitch.UseVisualStyleBackColor = true;
            this.buttonSwitch.Click += new System.EventHandler(this.buttonSwitch_Click);
            // 
            // groupBoxgraph
            // 
            this.groupBoxgraph.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left)));
            this.groupBoxgraph.Controls.Add(this.button3);
            this.groupBoxgraph.Controls.Add(this.button2);
            this.groupBoxgraph.Controls.Add(this.button1);
            this.groupBoxgraph.Controls.Add(this.buttonGclear);
            this.groupBoxgraph.Controls.Add(this.checkBox3);
            this.groupBoxgraph.Controls.Add(this.checkBox2);
            this.groupBoxgraph.Controls.Add(this.checkBox1);
            this.groupBoxgraph.Controls.Add(this.chart1);
            this.groupBoxgraph.Location = new System.Drawing.Point(17, 144);
            this.groupBoxgraph.Margin = new System.Windows.Forms.Padding(4);
            this.groupBoxgraph.Name = "groupBoxgraph";
            this.groupBoxgraph.Padding = new System.Windows.Forms.Padding(4);
            this.groupBoxgraph.Size = new System.Drawing.Size(1287, 572);
            this.groupBoxgraph.TabIndex = 5;
            this.groupBoxgraph.TabStop = false;
            this.groupBoxgraph.Text = "波形显示区";
            // 
            // button3
            // 
            this.button3.Location = new System.Drawing.Point(340, 39);
            this.button3.Name = "button3";
            this.button3.Size = new System.Drawing.Size(80, 42);
            this.button3.TabIndex = 7;
            this.button3.Text = "通道三";
            this.button3.UseVisualStyleBackColor = true;
            // 
            // button2
            // 
            this.button2.Location = new System.Drawing.Point(195, 39);
            this.button2.Name = "button2";
            this.button2.Size = new System.Drawing.Size(80, 42);
            this.button2.TabIndex = 6;
            this.button2.Text = "通道二";
            this.button2.UseVisualStyleBackColor = true;
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(46, 39);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(80, 42);
            this.button1.TabIndex = 5;
            this.button1.Text = "通道一";
            this.button1.UseVisualStyleBackColor = true;
            // 
            // buttonGclear
            // 
            this.buttonGclear.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Bottom | System.Windows.Forms.AnchorStyles.Left)));
            this.buttonGclear.Location = new System.Drawing.Point(539, 535);
            this.buttonGclear.Margin = new System.Windows.Forms.Padding(4);
            this.buttonGclear.Name = "buttonGclear";
            this.buttonGclear.Size = new System.Drawing.Size(131, 29);
            this.buttonGclear.TabIndex = 4;
            this.buttonGclear.Text = "清除波形";
            this.buttonGclear.UseVisualStyleBackColor = true;
            this.buttonGclear.Click += new System.EventHandler(this.buttonGclear_Click);
            // 
            // checkBox3
            // 
            this.checkBox3.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.checkBox3.AutoSize = true;
            this.checkBox3.Location = new System.Drawing.Point(427, 53);
            this.checkBox3.Margin = new System.Windows.Forms.Padding(4);
            this.checkBox3.Name = "checkBox3";
            this.checkBox3.Size = new System.Drawing.Size(18, 17);
            this.checkBox3.TabIndex = 3;
            this.checkBox3.UseVisualStyleBackColor = true;
            // 
            // checkBox2
            // 
            this.checkBox2.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.checkBox2.AutoSize = true;
            this.checkBox2.Location = new System.Drawing.Point(282, 53);
            this.checkBox2.Margin = new System.Windows.Forms.Padding(4);
            this.checkBox2.Name = "checkBox2";
            this.checkBox2.Size = new System.Drawing.Size(18, 17);
            this.checkBox2.TabIndex = 2;
            this.checkBox2.UseVisualStyleBackColor = true;
            // 
            // checkBox1
            // 
            this.checkBox1.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.checkBox1.AutoSize = true;
            this.checkBox1.Location = new System.Drawing.Point(133, 53);
            this.checkBox1.Margin = new System.Windows.Forms.Padding(4);
            this.checkBox1.Name = "checkBox1";
            this.checkBox1.Size = new System.Drawing.Size(18, 17);
            this.checkBox1.TabIndex = 1;
            this.checkBox1.UseVisualStyleBackColor = true;
            // 
            // chart1
            // 
            this.chart1.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.chart1.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(255)))), ((int)(((byte)(255)))), ((int)(((byte)(192)))));
            chartArea1.AxisX.Interval = 5D;
            chartArea1.AxisX.Minimum = 0D;
            chartArea1.AxisX.MinorGrid.Interval = 100D;
            chartArea1.AxisX.MinorGrid.IntervalOffset = double.NaN;
            chartArea1.AxisX.MinorGrid.IntervalOffsetType = System.Windows.Forms.DataVisualization.Charting.DateTimeIntervalType.NotSet;
            chartArea1.AxisX.MinorGrid.IntervalType = System.Windows.Forms.DataVisualization.Charting.DateTimeIntervalType.NotSet;
            chartArea1.AxisY.Interval = 0.5D;
            chartArea1.AxisY.Maximum = 4D;
            chartArea1.AxisY.Minimum = -1D;
            chartArea1.BackColor = System.Drawing.Color.FromArgb(((int)(((byte)(255)))), ((int)(((byte)(224)))), ((int)(((byte)(192)))));
            chartArea1.Name = "ChartArea1";
            this.chart1.ChartAreas.Add(chartArea1);
            legend1.Name = "Legend1";
            legend1.Title = "通道曲线：";
            legend1.TitleBackColor = System.Drawing.Color.White;
            legend1.TitleFont = new System.Drawing.Font("微软雅黑", 8.25F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            legend1.TitleSeparator = System.Windows.Forms.DataVisualization.Charting.LegendSeparatorStyle.ThickGradientLine;
            this.chart1.Legends.Add(legend1);
            this.chart1.Location = new System.Drawing.Point(8, 88);
            this.chart1.Margin = new System.Windows.Forms.Padding(4);
            this.chart1.Name = "chart1";
            series1.BorderWidth = 2;
            series1.ChartArea = "ChartArea1";
            series1.ChartType = System.Windows.Forms.DataVisualization.Charting.SeriesChartType.Spline;
            series1.Color = System.Drawing.Color.Blue;
            series1.Legend = "Legend1";
            series1.MarkerSize = 100;
            series1.Name = "通道一";
            series2.BorderWidth = 2;
            series2.ChartArea = "ChartArea1";
            series2.ChartType = System.Windows.Forms.DataVisualization.Charting.SeriesChartType.Spline;
            series2.Color = System.Drawing.Color.Fuchsia;
            series2.Legend = "Legend1";
            series2.MarkerSize = 100;
            series2.Name = "通道二";
            series3.BorderWidth = 2;
            series3.ChartArea = "ChartArea1";
            series3.ChartType = System.Windows.Forms.DataVisualization.Charting.SeriesChartType.Spline;
            series3.Color = System.Drawing.Color.Red;
            series3.Legend = "Legend1";
            series3.MarkerSize = 100;
            series3.Name = "通道三";
            this.chart1.Series.Add(series1);
            this.chart1.Series.Add(series2);
            this.chart1.Series.Add(series3);
            this.chart1.Size = new System.Drawing.Size(1271, 437);
            this.chart1.TabIndex = 0;
            this.chart1.Text = "chart1";
            title1.BackColor = System.Drawing.Color.Transparent;
            title1.Font = new System.Drawing.Font("微软雅黑", 12F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            title1.Name = "Title1";
            title1.Text = "多通道AD采样数据波形显示";
            this.chart1.Titles.Add(title1);
     
            // 
            // Oscilloscope
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 15F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1351, 720);
            this.Controls.Add(this.groupBoxgraph);
            this.Controls.Add(this.groupBoxCom);
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Margin = new System.Windows.Forms.Padding(4);
            this.Name = "Oscilloscope";
            this.Text = "采样波形显示";
            this.groupBoxCom.ResumeLayout(false);
            this.groupBoxCom.PerformLayout();
            this.groupBoxgraph.ResumeLayout(false);
            this.groupBoxgraph.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.chart1)).EndInit();
            this.ResumeLayout(false);

        }

        #endregion

        private System.IO.Ports.SerialPort serialPort1;
        private System.Windows.Forms.GroupBox groupBoxCom;
        private System.Windows.Forms.Label labelPort;
        private System.Windows.Forms.Button buttonSwitch;
        private System.Windows.Forms.ComboBox comboBoxStopBit;
        private System.Windows.Forms.Label labelStopBit;
        private System.Windows.Forms.ComboBox comboBoxCheck;
        private System.Windows.Forms.Label labelCheck;
        private System.Windows.Forms.ComboBox comboBoxData;
        private System.Windows.Forms.Label labelData;
        private System.Windows.Forms.ComboBox comboBoxBaudRate;
        private System.Windows.Forms.Label labelBaudRate;
        private System.Windows.Forms.ComboBox comboBoxPort;
        private System.Windows.Forms.Label labelStatus;
        private System.Windows.Forms.Label labelRecFrameNum;
        private System.Windows.Forms.Label labelRecFrameCount;
        private System.Windows.Forms.Label labelRecByteCount;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Button buttonClear;
        private System.Windows.Forms.GroupBox groupBoxgraph;
        private System.Windows.Forms.DataVisualization.Charting.Chart chart1;
        private System.Windows.Forms.CheckBox checkBox3;
        private System.Windows.Forms.CheckBox checkBox2;
        private System.Windows.Forms.CheckBox checkBox1;
        private System.Windows.Forms.Button buttonGclear;
        private System.Windows.Forms.Button button3;
        private System.Windows.Forms.Button button2;
        private System.Windows.Forms.Button button1;
    }
}


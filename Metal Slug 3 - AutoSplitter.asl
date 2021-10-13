


state("mslug3")
{

}

state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
}

state("fcadefbneo")
{
	int pointerScreen : 0x02D0E300, 0x4, 0xF4;
}





startup
{
	
	//A function that finds an array of bytes in memory
	Func<Process, SigScanTarget, IntPtr> FindArray = (process, target) =>
	{

		IntPtr pointer = IntPtr.Zero;
		
		foreach (var page in process.MemoryPages())
		{

			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);

			pointer = scanner.Scan(target);

			if (pointer != IntPtr.Zero) break;

		}
		
		return pointer;

	};
	
	vars.FindArray = FindArray;



	//A function that reads an array of 60 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[60];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 60, out bytes);

		if (!succes)
		{
			print("[MS3 AutoSplitter] Failed to read screen");
		}

		return bytes;

	};

	vars.ReadArray = ReadArray;



	//A function that matches two arrays of bytes
	Func<byte[], byte[], int, bool> MatchArray = (bytes, colors, maxOffset) =>
	{

		if (bytes == null)
		{
			return false;
		}
		
		for (int j = 0; j <= maxOffset; j++)
		{

			bool match = true;

			for (int i = 0; i+j < bytes.Length && i < colors.Length; i++)
			{
				if (bytes[i+j] != colors[i])
				{
					match = false;

					break;
				}
			}

			if (match == true) return true;

		}
		
		return false;

	};
	
	vars.MatchArray = MatchArray;



	//A function that prints an array of bytes
	Action<byte[]> PrintArray = (bytes) =>
	{

		if (bytes == null)
		{
			print("[MS3 AutoSplitter] Bytes are null");
		}

		else
		{
			var str = new System.Text.StringBuilder();

			for (int i = 0; i < bytes.Length; i++)
			{
				str.Append(bytes[i].ToString());

				str.Append(",");

				if (i % 4 == 3) str.Append("\n");

				else str.Append("\t");
			}

			print(str.ToString());
		}
	};

	vars.PrintArray = PrintArray;

	

	//Names for splits, purely for debug
	vars.splitNames = new string[] {	
										"Idle",
										"Priming Mission 1",
										"Spliting Mission 1",
										"Priming Mission 2",
										"Spliting Mission 2",
										"Priming Mission 3",
										"Spliting Mission 3",
										"Priming Mission 4",
										"Spliting Mission 4",
										"Priming Mission 5 Morden",
										"Spliting Mission 5 Morden",
										"Priming Mission 5 Galaga",
										"Spliting Mission 5 Galaga",
										"Priming Mission 5 FakeRoot",
										"Spliting Mission 5 FakeRoot",
										"Priming Mission 5 TrueRoot",
										"Spliting Mission 5 TrueRoot"
									};



	//Should we reset and restart the timer
	vars.restart = false;



	//The time at which the last reset happenend
	vars.prevRestartTime = Environment.TickCount;



	//An array of bytes to find the screen's pixel array memory region
	vars.scannerTargetScreen = new SigScanTarget(0, "10 08 00 00 ?? ?? 00 ?? ?? ?? ?? 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 20");



	//The pointer to the screen's pixel array memory region, once we found it with the scan
	vars.pointerScreen = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;



	//The time at which the last scan for the screen region happenend
	vars.prevScanTimeScreen = -1;



	//The split/state we are currently on
	vars.splitCounter = 0;
	


	//A local tickCount to do stuff sometimes
	vars.localTickCount = 0;

}





init
{
	
	//Set refresh rate
	refreshRate = 70;



	/*
	 * 
	 * The various color arrays we will be checking for throughout the game
	 * Colors must be formated as : Blue, Green, Red, Alpha
	 *
	 * On the Steam version, Alpha seems to always be 255
	 * On the Steam version, the offset is 0x40 + X * 0x4 + Y * 0x800
	 *
	 * On the WinKawaks version, Alpha seems to always be 0
	 * On the WinKawaks version, the offset is X * 0x4 + Y * 0x500
	 * 
	 */



	if(game.ProcessName.Equals("WinKawaks"))
	{
		
		//The water splash when the character hits the water at the start of mission 1
		//Starts at pixel ( 65 , 180 )
		vars.colorsRunStart = new byte[]		{
													208, 248, 240, 0,
													168, 232, 200, 0,
													160, 208, 168, 0,
													208, 248, 240, 0,
													208, 248, 240, 0,
													160, 208, 168, 0,
													168, 232, 200, 0,
													160, 208, 168, 0,
													168, 232, 200, 0,
													208, 248, 240, 0
												};
		
		vars.offsetRunStart = 0x357FC;
		
		
		
		//The grey lining of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0,
													184, 168, 160, 0
												};

		vars.offsetUI = 0x2740;
		
		vars.offsetUI2 = 0x28C0;
		

		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   0,
													248, 248, 248, 0,
													0,   0,   120, 0,
													48,  208, 248, 0,
													24,  144, 248, 0,
													48,  208, 248, 0,
													24,  144, 248, 0,
													48,  208, 248, 0,
													248, 248, 248, 0,
													0,   0,   0,   0
												};
		
		vars.offsetExclamationMark = 0x21C9C;
		
		
		
		//The rocket we use to go to space
		//Starts at pixel ( 158 , 92 )
		vars.colorsRocket = new byte[]			{
													32,  56,  72,  0,
													16,  32,  72,  0,
													16,  32,  72,  0,
													24,  48,  96,  0,
													16,  32,  72,  0,
													16,  32,  72,  0,
													24,  48,  96,  0,
													80,  112, 128, 0,
													80,  112, 128, 0,
													80,  112, 128, 0
												};
		
		vars.offsetRocket = 0x1B778;
		
		

		//The inner wall of Rugname
		//Starts at pixel ( 146 , 35 )
		vars.colorsRugnameIn = new byte[]		{
													88,  88,  80,  0,
													112, 112, 104, 0,
													136, 144, 144, 0,
													112, 112, 104, 0,
													88,  88,  80,  0,
													112, 112, 104, 0,
													112, 112, 104, 0,
													88,  88,  80,  0,
													112, 112, 104, 0,
													136, 144, 144, 0
												};
		
		vars.offsetRugnameIn = 0xA888;
		


		//The shattered glass on Fake Root's brain when he is defeated
		//Use two arrays because they can be obscured by debris
		//Start at pixel ( 130 , 47 ) and ( 206 , 63 )
		vars.colorsFakeRoot1 = new byte[]		{
													128, 152, 168, 0,
													96,  120, 136, 0,
													200, 224, 248, 0,
													200, 224, 248, 0,
													200, 224, 248, 0,
													8,   32,  48,  0,
													8,   32,  48,  0,
													168, 192, 216, 0,
													200, 224, 248, 0,
													128, 152, 168, 0
												};
		
		vars.colorsFakeRoot2 = new byte[]		{
													128, 152, 176, 0,
													168, 192, 216, 0,
													8,   32,  48,  0,
													8,   32,  48,  0,
													168, 192, 216, 0,
													168, 192, 216, 0,
													72,  96,  120, 0,
													0,   8,   24,  0,
													0,   16,  32,  0,
													32,  56,  72,  0
												};
		
		vars.offsetFakeRoot1 = 0xE148;
		
		vars.offsetFakeRoot2 = 0x12E78;
		
		
		
		//The rim of Rugname when we exit
		//Starts at pixel ( 36, 0 )
		vars.colorsRugnameOut = new byte[]		{
													88,  104, 104, 0,
													248, 248, 248, 0,
													24,  40,  40,  0,
													24,  40,  40,  0,
													24,  40,  40,  0,
													64,  80,  80,  0,
													40,  56,  56,  0,
													40,  56,  56,  0,
													24,  40,  40,  0,
													128, 144, 144, 0
												};
		
		vars.offsetRugnameOut = 0x90;
		
		
		
		//The background black when True Root dies (3 frames just to be sure)
		//Starts at pixel ( 36, 0 ) // ( 165 , 0 ) // ( 274 , 181 )
		vars.colorsTrueRoot1 = new byte[]		{
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0
												};

		vars.colorsTrueRoot2 = new byte[]		{
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0
												};

		vars.colorsTrueRoot3 = new byte[]		{
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0
												};
		
		vars.offsetTrueRoot1 = 0x90;

		vars.offsetTrueRoot2 = 0x294;

		vars.offsetTrueRoot3 = 0x38D48;
		
		

		//Pure white
		vars.colorsWhite = new byte[]		{
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													248, 248, 248, 0
												};
	}



	else if (game.ProcessName.Equals("fcadefbneo"))
	{
		
		//The water splash when the character hits the water at the start of mission 1
		//Starts at pixel ( 65 , 180 )
		vars.colorsRunStart = new byte[]		{
													214, 255, 247, 0,
													214, 255, 247, 0,
													173, 239, 206, 0,
													173, 239, 206, 0,
													165, 214, 173, 0,
													165, 214, 173, 0,
													214, 255, 247, 0,
													214, 255, 247, 0,
													214, 255, 247, 0,
													214, 255, 247, 0,
													165, 214, 173, 0,
													165, 214, 173, 0,
													173, 239, 206, 0,
													173, 239, 206, 0,
													165, 214, 173, 0
												};
		
		vars.offsetRunStart = 0xD5E08;
		
		
		
		//The grey lining of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0,
													189, 173, 165, 0
												};

		vars.offsetUI = 0x9A80;
		
		vars.offsetUI2 = 0x9D80;
		

		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   0,
													0,   0,   0,   0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													0,   0,   123, 0,
													0,   0,   123, 0,
													49,  214, 255, 0,
													49,  214, 255, 0,
													24,  148, 255, 0,
													24,  148, 255, 0,
													49,  214, 255, 0,
													49,  214, 255, 0,
													24,  148, 255, 0,
													24,  148, 255, 0,
													49,  214, 255, 0
												};
		
		vars.offsetExclamationMark = 0x86AB8;
		
		
		
		//The rocket we use to go to space
		//Starts at pixel ( 158 , 92 )
		vars.colorsRocket = new byte[]			{
													33,  57,  74,  0,
													33,  57,  74,  0,
													16,  33,  74,  0,
													16,  33,  74,  0,
													16,  33,  74,  0,
													16,  33,  74,  0,
													24,  49,  99,  0,
													24,  49,  99,  0,
													16,  33,  74,  0,
													16,  33,  74,  0,
													16,  33,  74,  0,
													16,  33,  74,  0,
													24,  49,  99,  0,
													24,  49,  99,  0,
													82,  115, 132, 0
												};
		
		vars.offsetRocket = 0x6D8F0;
		
		
		
		//The inner wall of Rugname
		//Starts at pixel ( 146 , 35 )
		vars.colorsRugnameIn = new byte[]		{
													90,  90,  82,  0,
													90,  90,  82,  0,
													115, 115, 107, 0,
													115, 115, 107, 0,
													140, 148, 148, 0,
													140, 148, 148, 0,
													115, 115, 107, 0,
													115, 115, 107, 0,
													90,  90,  82,  0,
													90,  90,  82,  0,
													115, 115, 107, 0,
													115, 115, 107, 0,
													115, 115, 107, 0,
													115, 115, 107, 0,
													90,  90,  82,  0
												};
		
		vars.offsetRugnameIn = 0x29D90;
		
		
		
		//The shattered glass on Fake Root's brain when he is defeated
		//Use two arrays because they can be obscured by debris
		//Start at pixel ( 130 , 47 ) and ( 206 , 63 )
		vars.colorsFakeRoot1 = new byte[]		{
													132, 156, 173, 0,
													132, 156, 173, 0,
													99,  123, 140, 0,
													99,  123, 140, 0,
													206, 231, 255, 0,
													206, 231, 255, 0,
													206, 231, 255, 0,
													206, 231, 255, 0,
													206, 231, 255, 0,
													206, 231, 255, 0,
													8,   33,  49,  0,
													8,   33,  49,  0,
													8,   33,  49,  0,
													8,   33,  49,  0,
													173, 198, 222, 0
												};
		
		vars.colorsFakeRoot2 = new byte[]		{
													132, 156, 181, 0,
													132, 156, 181, 0,
													173, 198, 222, 0,
													173, 198, 222, 0,
													8,   33,  49,  0,
													8,   33,  49,  0,
													8,   33,  49,  0,
													8,   33,  49,  0,
													173, 198, 222, 0,
													173, 198, 222, 0,
													173, 198, 222, 0,
													173, 198, 222, 0,
													74,  99,  123, 0,
													74,  99,  123, 0,
													0,   8,   24,  0
												};
		
		vars.offsetFakeRoot1 = 0x38110;
		
		vars.offsetFakeRoot2 = 0x4B370;
		
		
		
		//The rim of Rugname when we exit
		//Starts at pixel ( 36, 0 )
		vars.colorsRugnameOut = new byte[]		{
													90,  107, 107, 0,
													90,  107, 107, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													24,  41,  41,  0,
													24,  41,  41,  0,
													24,  41,  41,  0,
													24,  41,  41,  0,
													24,  41,  41,  0,
													24,  41,  41,  0,
													66,  82,  82,  0,
													66,  82,  82,  0,
													41,  57,  57,  0,
													41,  57,  57,  0,
													41,  57,  57,  0
												};
		
		vars.offsetRugnameOut = 0x120;
		
		
		
		//The background black when True Root dies
		//Starts at pixel ( 36, 0 ) // ( 165 , 0 ) // ( 274 , 181 )
		vars.colorsTrueRoot1 = new byte[]		{
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0
												};

		vars.colorsTrueRoot2 = new byte[]		{
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0,
													8,   8,   8,   0
												};

		vars.colorsTrueRoot3 = new byte[]		{
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0,
													16,  16,  16,  0
												};

		vars.offsetTrueRoot1 = 0x120;

		vars.offsetTrueRoot2 = 0x528;

		vars.offsetTrueRoot3 = 0xD7790;
		
		

		//Pure white
		vars.colorsWhite = new byte[]		{
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0
												};
	}



	else //if(game.ProcessName.Equals("mslug3"))
	{
		
		//The water splash when the character hits the water at the start of mission 1
		//Starts at pixel ( 65 , 180 )
		vars.colorsRunStart = new byte[]		{
													214, 251, 247, 255,
													173, 235, 206, 255,
													165, 211, 173, 255,
													214, 251, 247, 255,
													214, 251, 247, 255,
													165, 211, 173, 255,
													173, 235, 206, 255,
													165, 211, 173, 255,
													173, 235, 206, 255,
													214, 251, 247, 255
												};
		
		vars.offsetRunStart = 0x5A12B;
		
		
		
		//The grey of the UI
		//Starts at pixel ( 80 , 8 ) for player 1
		//Starts at pixel ( 176 , 8 ) for player 2
		vars.colorsUI = new byte[]				{
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255,
													189, 170, 165, 255
												};
		
		vars.offsetUI = 0x416F;
		
		vars.offsetUI2 = 0x42EF;
		

		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,   0,   0,   255,
													255, 251, 255, 255,
													0,   0,   123, 255,
													49,  211, 255, 255,
													24,  146, 255, 255,
													49,  211, 255, 255,
													24,  146, 255, 255,
													49,  211, 255, 255,
													255, 251, 255, 255,
													0,   0,   0,   255
												};

		vars.offsetExclamationMark = 0x38C0B;
		
		
		
		//The rocket we use to go to space
		//Starts at pixel ( 158 , 92 )
		vars.colorsRocket = new byte[]			{
													33,  56,  74,  255,
													16,  32,  74,  255,
													16,  32,  74,  255,
													24,  48,  99,  255,
													16,  32,  74,  255,
													16,  32,  74,  255,
													24,  48,  99,  255,
													82,  113, 132, 255,
													82,  113, 132, 255,
													82,  113, 132, 255
												};
		
		vars.offsetRocket = 0x2E2A7;
		
		
		
		//The inner wall of Rugname
		//Starts at pixel ( 146 , 35 )
		vars.colorsRugnameIn = new byte[]		{
													90,  89,  82,  255,
													115, 113, 107, 255,
													140, 146, 148, 255,
													115, 113, 107, 255,
													90,  89,  82,  255,
													115, 113, 107, 255,
													115, 113, 107, 255,
													90,  89,  82,  255,
													115, 113, 107, 255,
													140, 146, 148, 255
												};
		
		vars.offsetRugnameIn = 0x11A77;
		
		
		
		//The shattered glass on Fake Root's brain when he is defeated
		//Use two arrays because they can be obscured by debris
		//Start at pixel ( 130 , 47 ) and ( 206 , 63 )
		vars.colorsFakeRoot1 = new byte[]		{
													132, 154, 173, 255,
													99,  121, 140, 255,
													206, 227, 255, 255,
													206, 227, 255, 255,
													206, 227, 255, 255,
													8,   32,  49,  255,
													8,   32,  49,  255,
													173, 195, 222, 255,
													206, 227, 255, 255,
													132, 154, 173, 255
												};
		
		vars.colorsFakeRoot2 = new byte[]		{
													132, 154, 181, 255,
													173, 195, 222, 255,
													8,   32,  49,  255,
													8,   32,  49,  255,
													173, 195, 222, 255,
													173, 195, 222, 255,
													74,  97,  123, 255,
													0,   8,   24,  255,
													0,   16,  33,  255,
													33,  56,  74,  255
												};
		
		vars.offsetFakeRoot1 = 0x17A37;
		
		vars.offsetFakeRoot2 = 0x1FB67;
		
		
		
		//The rim of Rugname when we exit
		//Starts at pixel ( 36, 0 )
		vars.colorsRugnameOut = new byte[]		{
													90,  105, 107, 255,
													255, 251, 255, 255,
													24,  40,  41,  255,
													24,  40,  41,  255,
													24,  40,  41,  255,
													66,  81,  82,  255,
													41,  56,  57,  255,
													41,  56,  57,  255,
													24,  40,  41,  255,
													132, 146, 148, 255
												};
		
		vars.offsetRugnameOut = 0xBF;
		
		
		
		//The background black when True Root dies
		//Starts at pixel ( 36, 0 ) // ( 165 , 0 ) // ( 274 , 181 )
		vars.colorsTrueRoot1 = new byte[]		{
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255
												};
		
		vars.colorsTrueRoot2 = new byte[]		{
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255,
													8,   8,   8,   255
												};
		
		vars.colorsTrueRoot3 = new byte[]		{
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255,
													16,  16,  16,  255
												};
		
		vars.offsetTrueRoot1 = 0xBF;

		vars.offsetTrueRoot2 = 0x2C3;

		vars.offsetTrueRoot3 = 0x5AC77;
		
		
		
		//Pure white
		vars.colorsWhite = new byte[]			{
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													255, 251, 255, 255
												};
	}
}





exit
{

	//The pointers and watchers are no longer valid
	vars.pointerScreen = IntPtr.Zero;
	
	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	
}





update
{
	
	//Increase local tickCount
	vars.localTickCount++;

	

	//Try to find the screen
	//For Kawaks and FightCade, follow the pointer path
	if(game.ProcessName.Equals("WinKawaks") || game.ProcessName.Equals("fcadefbneo"))
	{
		vars.pointerScreen = new IntPtr(current.pointerScreen);
	}
	
	//For Steam, do a scan
	else
	{

		//If the screen region changed place in memory, void the pointer
		vars.watcherScreen.Update(game);
		
		if (vars.watcherScreen.Changed)
		{
			
			vars.pointerScreen = IntPtr.Zero;

		}

		
		
		//If the screen pointer is void
		if (vars.pointerScreen == IntPtr.Zero)
		{
		
			//If the screen scan cooldown has elapsed
			var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeScreen;
	
			if (timeSinceLastScan > 300)
			{
				
				//Notify
				print("[MS3 AutoSplitter] Scanning for screen");



				//Scan for the screen
				vars.pointerScreen = vars.FindArray(game, vars.scannerTargetScreen);
				
				
				
				//If the scan was successful
				if (vars.pointerScreen != IntPtr.Zero)
				{
					
					//Notify
					print("[MS3 AutoSplitter] Found screen");



					//Create a new memory watcher
					vars.watcherScreen = new MemoryWatcher<short>(vars.pointerScreen);

					vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

				}
			
			
			
				//Write down scan time
				vars.prevScanTimeScreen = Environment.TickCount;
			
			}
		}
	}
	
	

	//If we know where the screen is
	if (vars.pointerScreen != IntPtr.Zero)
	{
		
		/*
		//Debug print
		if (vars.localTickCount % 10 == 0)
		{
			print("[MS3 AutoSplitter] Debug " + vars.splitCounter.ToString());

			vars.PrintArray(vars.ReadArray(game, vars.offsetFakeRoot2));
		}
		*/
		
		
		
		//Check time since last reset, don't reset if we already reset in the last second
		var timeSinceLastReset = Environment.TickCount - vars.prevRestartTime;
		
		if (timeSinceLastReset < 1000)
		{
			vars.restart = false;
		}
	
		//Otherwise, check if we should start/restart the timer
		else
		{
			vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetRunStart), vars.colorsRunStart, 32);
		}
	}
}





reset
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevRestartTime = Environment.TickCount;

		vars.prevScanTimeScreen = -1;

		return true;
	}
}





start
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevRestartTime = Environment.TickCount;

		vars.prevScanTimeScreen = -1;
		
		return true;
	}
}





split
{
	
	//If we dont know where the screen is, don't do anything
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Split when the UI disappears for both players
	if
	(
			vars.splitCounter == 1
		||	vars.splitCounter == 3
		||	vars.splitCounter == 5
		||	vars.splitCounter == 7
		||	vars.splitCounter == 9
		||	vars.splitCounter == 11
		||	vars.splitCounter == 13
	)
	{
		byte[] pixels = vars.ReadArray(game, vars.offsetUI);

		byte[] pixels2 = vars.ReadArray(game, vars.offsetUI2);
		
		if (!vars.MatchArray(pixels, vars.colorsUI, 0) && !vars.MatchArray(pixels2, vars.colorsUI, 0))
		{
			vars.splitCounter++;
			
			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);

			return true;
		}
	}



	//Prime when we see the exclamation mark
	else if
	(
			vars.splitCounter == 0
		||	vars.splitCounter == 2
		||	vars.splitCounter == 4
		||	vars.splitCounter == 6
	)
	{
		byte[] pixels = vars.ReadArray(game, vars.offsetExclamationMark);
	
		if (vars.MatchArray(pixels, vars.colorsExclamationMark, 0))
		{
			vars.splitCounter++;

			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);
		}
	}

	

	//Prime when we see the rocket
	else if (vars.splitCounter == 8)
	{
		byte[] pixels = vars.ReadArray(game, vars.offsetRocket);
		
		if (vars.MatchArray(pixels, vars.colorsRocket, 0))
		{
			vars.splitCounter++;

			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);
		}
	}

	
	
	//Prime when we see the inner wall of Rugname
	else if (vars.splitCounter == 10)
	{
		byte[] pixels = vars.ReadArray(game, vars.offsetRugnameIn);
		
		if (vars.MatchArray(pixels, vars.colorsRugnameIn, 0))
		{
			vars.splitCounter++;

			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);
		}
	}


	
	//Prime when we see Fake Root destroyed
	else if (vars.splitCounter == 12)
	{
		byte[] pixels1 = vars.ReadArray(game, vars.offsetFakeRoot1);

		byte[] pixels2 = vars.ReadArray(game, vars.offsetFakeRoot2);
		
		if (vars.MatchArray(pixels1, vars.colorsFakeRoot1, 0) || vars.MatchArray(pixels2, vars.colorsFakeRoot2, 0))
		{
			vars.splitCounter++;

			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);
		}
	}


	
	//Prime when we see the outer wall of Rugname
	else if (vars.splitCounter == 14)
	{
		byte[] pixels = vars.ReadArray(game, vars.offsetRugnameOut);
		
		if (vars.MatchArray(pixels, vars.colorsRugnameOut, 0))
		{
			vars.splitCounter++;

			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);
		}
	}


	
	//For True Rootmars
	if (vars.splitCounter >= 15)
	{
		
		//Split when the background becomes completely black
		//We need to check multiple arrays, because the player or the boss's attacks might be obscuring some of them
		byte[] pixels1 = vars.ReadArray(game, vars.offsetTrueRoot1);

		byte[] pixels2 = vars.ReadArray(game, vars.offsetTrueRoot2);

		byte[] pixels3 = vars.ReadArray(game, vars.offsetTrueRoot3);
		
		if
		(
			vars.MatchArray(pixels1, vars.colorsTrueRoot1, 0)	||
			vars.MatchArray(pixels2, vars.colorsTrueRoot1, 0)	||
			vars.MatchArray(pixels3, vars.colorsTrueRoot1, 0)	||
			vars.MatchArray(pixels1, vars.colorsTrueRoot2, 0)	||
			vars.MatchArray(pixels2, vars.colorsTrueRoot2, 0)	||
			vars.MatchArray(pixels3, vars.colorsTrueRoot2, 0)	||
			vars.MatchArray(pixels1, vars.colorsTrueRoot3, 0)	||
			vars.MatchArray(pixels2, vars.colorsTrueRoot3, 0)	||
			vars.MatchArray(pixels3, vars.colorsTrueRoot3, 0)
		)
		{
			vars.splitCounter++;
			
			print("[MS3 AutoSplitter] " + vars.splitNames[vars.splitCounter]);
			
			return true;
		}
	}
}

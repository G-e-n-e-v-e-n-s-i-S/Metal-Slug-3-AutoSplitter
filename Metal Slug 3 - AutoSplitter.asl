


state("mslug3")
{

}

state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
}

state("fcadefbneo")
{
	int pointerScreen : 0x02CC2280, 0x4, 0x4, 0x14;
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
										"Mission 1 Beach",
										"Mission 1 Tanker",
										"Mission 1 Huge Hermit",
										"Mission 2",
										"Mission 3 Cutscene",
										"Mission 3 Water",
										"Mission 3 Oil Rig",
										"Mission 3 Jupiter King",
										"Mission 4 Desert",
										"Mission 4 Pyramid",
										"Mission 4 Sol Dae Rokker",
										"Mission 5 Plane Platform",
										"Mission 5 Allen",
										"Mission 5 Morden",
										"Mission 5 Rugname",
										"Mission 5 Galaga",
										"Mission 5 Pillar Room",
										"Mission 5 Tortue Room",
										"Mission 5 Kamikaze Room",
										"Mission 5 FakeRoot",
										"Mission 5 Slug Room",
										"Mission 5 Cloning Room",
										"Mission 5 Red Room",
										"Mission 5 TrueRoot"
									};



	//Should we reset and restart the timer
	vars.restart = false;



	//An array of bytes to find the screen's pixel array memory region
	vars.scannerTargetScreen = new SigScanTarget(0, "10 08 00 00 ?? ?? 00 ?? ?? ?? ?? 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 20");



	//The pointer to the screen's pixel array memory region, once we found it with the scan
	vars.pointerScreen = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherScreen = new MemoryWatcher<short>(IntPtr.Zero);

	vars.watcherScreen.FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;



	//The time at which the last scan for the screen region happenend
	vars.prevScanTimeScreen = -1;

	

	//Is the UI present on screen now? Was it last frame? How many frames was it on?
	vars.UIOnScreenCurrent = false;

	vars.UIOnScreenOld = false;

	vars.UIOnScreenCount = 0;



	//The split/state we are currently on
	vars.splitCounter = 0;
	


	//A local tickCount to do stuff sometimes
	vars.localTickCount = 0;

}





init
{
	
	//Set refresh rate
	refreshRate = 60;



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
		//Starts at pixel ( 80 , 8 )
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
		
		
		
		//The "CONTINUE" text
		//Starts at pixel ( 16 , 20 )
		vars.colorsContinue = new byte[]		{
													0,   0,   0,   0,
													248, 176, 184, 0,
													248, 152, 160, 0,
													248, 176, 184, 0,
													248, 152, 160, 0,
													248, 176, 184, 0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													248, 176, 184, 0
												};
		
		vars.offsetContinue = 0x5F40;
		
		
		
		//The digit from the character selection
		//Starts at pixel ( 16 , 12 )
		vars.colorsDigit = new byte[]		{
													0,   0,   0,   0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													248, 248, 248, 0,
													248, 248, 248, 0,
													0,   0,   0,   0
												};
		
		vars.offsetDigit = 0x3940;
		
		
		
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
		//Starts at pixel ( 80 , 8 )
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
		
		
		
		//The "CONTINUE" text
		//Starts at pixel ( 16 , 20 )
		vars.colorsContinue = new byte[]		{
													0,   0,   0,   0,
													0,   0,   0,   0,
													255, 181, 189, 0,
													255, 181, 189, 0,
													255, 156, 165, 0,
													255, 156, 165, 0,
													255, 181, 189, 0,
													255, 181, 189, 0,
													255, 156, 165, 0,
													255, 156, 165, 0,
													255, 181, 189, 0,
													255, 181, 189, 0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0
												};
		
		vars.offsetContinue = 0x17C80;
		
		
		
		//The digit from the character selection
		//Starts at pixel ( 16 , 12 )
		vars.colorsDigit = new byte[]		{
													0,   0,   0,   0,
													0,   0,   0,   0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													0,   0,   0,   0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													255, 255, 255, 0,
													0,   0,   0,   0
												};
		
		vars.offsetDigit = 0xE480;
		
		
		
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
		//Starts at pixel ( 80 , 8 )
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
		
		
		
		//The "CONTINUE" text
		//Starts at pixel ( 16 , 20 )
		vars.colorsContinue = new byte[]		{
													0,   0,   0,   255,
													255, 178, 189, 255,
													255, 154, 165, 255,
													255, 178, 189, 255,
													255, 154, 165, 255,
													255, 178, 189, 255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													255, 178, 189, 255
												};
		
		vars.offsetContinue = 0xA06F;
		
		
		
		//The digit from the character selection
		//Starts at pixel ( 16 , 12 )
		vars.colorsDigit = new byte[]			{
													0,   0,   0,   255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													0,   0,   0,   255,
													0,   0,   0,   255,
													255, 251, 255, 255,
													255, 251, 255, 255,
													0,   0,   0,   255
												};
		
		vars.offsetDigit = 0x606F;
	
		
		
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
	vars.localTickCount = vars.localTickCount + 1;

	

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

			vars.PrintArray(vars.ReadArray(game, vars.offsetContinue));
		}
		*/
		
		//Check if we should start/restart the timer
		vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetRunStart), vars.colorsRunStart, 32);

	}
}





reset
{
	
	if (vars.restart)
	{
		vars.UIOnScreenCurrent = false;

		vars.UIOnScreenOld = false;

		vars.UIOnScreenCount = 0;
		
		vars.splitCounter = 0;
		
		vars.prevScanTimeScreen = -1;

		return true;
	}
}





start
{
	
	if (vars.restart)
	{
		vars.UIOnScreenCurrent = false;

		vars.UIOnScreenOld = false;

		vars.UIOnScreenCount = 0;
		
		vars.splitCounter = 0;
		
		vars.prevScanTimeScreen = -1;
		
		return true;
	}
}





split
{
	
	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Check if the UI is on screen or not
	byte[] pixelsUI = vars.ReadArray(game, vars.offsetUI);
	
	byte[] pixelsContinue = vars.ReadArray(game, vars.offsetContinue);

	byte[] pixelsDigit = vars.ReadArray(game, vars.offsetDigit);
	
	if
	(
		vars.MatchArray(pixelsUI, vars.colorsUI, 0)				||
		vars.MatchArray(pixelsContinue, vars.colorsContinue, 0)	||
		vars.MatchArray(pixelsDigit, vars.colorsDigit, 0)
	)
	{
		vars.UIOnScreenCurrent = true;

		vars.UIOnScreenCount++;

		if (vars.UIOnScreenCount == refreshRate)
		{
			vars.splitCounter++;
		
			print("[MS3 AutoSplitter] Aquired:  " + vars.splitNames[vars.splitCounter]);
		}
	}

	else if
	(
		vars.MatchArray(pixelsUI, vars.colorsWhite, 0)
	)
	{
		vars.UIOnScreenCurrent = vars.UIOnScreenOld;
	}

	else
	{
		vars.UIOnScreenCurrent = false;
	}



	//Check if the UI just disappeared after being on screen for more than one second
	bool UIDisappeared = !vars.UIOnScreenCurrent && vars.UIOnScreenOld && vars.UIOnScreenCount >= refreshRate;
	
	
	
	//Update state of last frame
	vars.UIOnScreenOld = vars.UIOnScreenCurrent;
	
	if (!vars.UIOnScreenCurrent) vars.UIOnScreenCount = 0;

	

	//If the UI just disappeared, update split counter and maybe split
	if (UIDisappeared)
	{
		print("[MS3 AutoSplitter] Released: " + vars.splitNames[vars.splitCounter]);
		
		if
		(
			vars.splitCounter == 3	||
			vars.splitCounter == 4	||
			vars.splitCounter == 8	||
			vars.splitCounter == 11	||
			vars.splitCounter == 14	||
			vars.splitCounter == 16	||
			vars.splitCounter == 20
		)
		{
			return true;
		}
	}


	
	//For True Rootmars
	if (vars.splitCounter >= 24)
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
			
			return true;
		}
	}
}

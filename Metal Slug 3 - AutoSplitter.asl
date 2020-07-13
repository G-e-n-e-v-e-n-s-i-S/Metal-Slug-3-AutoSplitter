﻿
/*
 * 
 *	Okay here's the plan:
 *	Signature scan for the screen
 *	Look for the colors of arrays of pixels on screen
 *	Split when these arrays match some predictable values
 *	Signature scan for the health variable of the last boss
 *	Split when his health reaches zero
 * 
 */





state("mslug3")
{

}

state("WinKawaks")
{
	int pointerScreen : 0x0046B270;
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



	//A function that reads an array of 40 bytes in the screen memory
	Func<Process, int, byte[]> ReadArray = (process, offset) =>
	{

		byte[] bytes = new byte[40];

		bool succes = ExtensionMethods.ReadBytes(process, vars.pointerScreen + offset, 40, out bytes);

		if (!succes)
		{
			print("[MS3 AutoSplitter] Failed to read screen");
		}

		return bytes;

	};

	vars.ReadArray = ReadArray;



	//A function that matches two arrays of bytes
	Func<byte[], byte[], bool> MatchArray = (bytes, colors) =>
	{

		if (bytes == null)
		{
			return false;
		}

		for (int i = 0; i < bytes.Length; i++)
		{

			if (bytes[i] != colors[i])
			{
				return false;
			}
		}

		return true;

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



	//An array of bytes to find the boss's health variable
	vars.scannerTargetBossHealth = new SigScanTarget(22, "10 00 A0 A0 ?? 00 00 ?? ?? 01 00 ?? ?? 00 00 ?? ?? 01 00 ?? 00 ?? ?? ?? 09");

	
	
	//The pointer to the boss's health, once we found it with the scan
	vars.pointerBossHealth = IntPtr.Zero;



	//A watcher for this pointer
	vars.watcherBossHealth = new MemoryWatcher<short>(IntPtr.Zero);



	//The time at which the last scan happenend
	vars.prevScanTimeBossHealth = -1;



	//The time at which the last split happenend
	vars.prevSplitTime = -1;



	//The split/state we are currently on
	vars.splitCounter = 0;
	
}





init
{
	
	//Set refresh rate
	refreshRate = 33;


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
		vars.colorsWaterSplash = new byte[]		{
													208,	248,	240,	0,
													168,	232,	200,	0,
													160,	208,	168,	0,
													208,	248,	240,	0,
													208,	248,	240,	0,
													160,	208,	168,	0,
													168,	232,	200,	0,
													160,	208,	168,	0,
													168,	232,	200,	0,
													208,	248,	240,	0
												};
		
		vars.offsetWaterSplash = 0x35804;
		
		
		
		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,		0,		0,		0,
													248,	248,	248,	0,
													0,		0,		120,	0,
													48,		208,	248,	0,
													24,		144,	248,	0,
													48,		208,	248,	0,
													24,		144,	248,	0,
													48,		208,	248,	0,
													248,	248,	248,	0,
													0,		0,		0,		0
												};

		vars.offsetExclamationMark = 0x21C9C;



		//The nose of Morden when he hits the ground after falling from the Hi-Do
		//Starts at pixel ( 188 , 188 )
		vars.colorsMorden = new byte[]			{
													24,		48,		48,		0,
													24,		48,		48,		0,
													112,	144,	144,	0,
													112,	144,	144,	0,
													64,		96,		96,		0,
													160,	216,	248,	0,
													160,	216,	248,	0,
													224,	248,	248,	0,
													56,		96,		128,	0,
													0,		16,		16,		0
												};

		vars.offsetMorden =	0x37FF0;



		//The wall of Rugname we smash into
		//Starts at pixel ( 147 , 35 )
		vars.colorsRugname = new byte[]			{
													112,	112,	104,	0,
													136,	144,	144,	0,
													112,	112,	104,	0,
													88,		88,		80,		0,
													112,	112,	104,	0,
													112,	112,	104,	0,
													88,		88,		80,		0,
													112,	112,	104,	0,
													136,	144,	144,	0,
													112,	112,	104,	0
												};

		vars.offsetRugname = 0xA88C;



		//The foreground after defeating Fake Root, mingled with the second dither pattern of the screen fade
		//The screen shakes at 60Hz here, so we need two values to be sure
		//Starts at pixel ( 286 , 173 )
		vars.colorsFakeRoot1 = new byte[]		{
													0,		0,		0,		0,
													64,		104,	136,	0,
													48,		80,		112,	0,
													48,		80,		112,	0,
													0,		0,		0,		0,
													64,		104,	136,	0,
													64,		104,	136,	0,
													88,		136,	168,	0,
													0,		0,		0,		0,
													88,		136,	168,	0
												};

		vars.colorsFakeRoot2 = new byte[]		{
													0,		0,		0,		0,
													64,		104,	136,	0,
													88,		136,	168,	0,
													64,		104,	136,	0,
													0,		0,		0,		0,
													88,		136,	168,	0,
													88,		136,	168,	0,
													88,		136,	168,	0,
													0,		0,		0,		0,
													64,		104,	136,	0
												};

		vars.offsetFakeRoot = 0x33A38;



		//The rim of Rugname when we exit it just before fighting True Root
		//Starts at pixel ( 36, 0 )
		vars.colorsExit = new byte[]			{
													88,		104,	104,	0,
													248,	248,	248,	0,
													24,		40,		40,		0,
													24,		40,		40,		0,
													24,		40,		40,		0,
													64,		80,		80,		0,
													40,		56,		56,		0,
													40,		56,		56,		0,
													24,		40,		40,		0,
													128,	144,	144,	0
												};

		vars.offsetExit = 0x90;
		
		
		
		//The background black when True Root dies
		//Starts at pixel ( 36, 0 ) // ( 165 , 0 ) // ( 274 , 181 )
		vars.colorsTrueRoot = new byte[]		{
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0,
													0,		0,		0,		0
												};

		vars.offsetTrueRoot1 = 0x90;

		vars.offsetTrueRoot2 = 0x294;

		vars.offsetTrueRoot3 = 0x38D48;

	}



	else //if(game.ProcessName.Equals("mslug3"))
	{
		
		//The water splash when the character hits the water at the start of mission 1
		//Starts at pixel ( 65 , 180 )
		vars.colorsWaterSplash = new byte[]		{
													214,	251,	247,	255,
													173,	235,	206,	255,
													165,	211,	173,	255,
													214,	251,	247,	255,
													214,	251,	247,	255,
													165,	211,	173,	255,
													173,	235,	206,	255,
													165,	211,	173,	255,
													173,	235,	206,	255,
													214,	251,	247,	255
												};
		
		vars.offsetWaterSplash = 0x5A133;
	
		

		//The exclamation mark in the Mission Complete !" text
		//Starts at pixel ( 247 , 113 )
		vars.colorsExclamationMark = new byte[] {
													0,		0,		0,		255,
													255,	251,	255,	255,
													0,		0,		123,	255,
													49,		211,	255,	255,
													24,		146,	255,	255,
													49,		211,	255,	255,
													24,		146,	255,	255,
													49,		211,	255,	255,
													255,	251,	255,	255,
													0,		0,		0,		255
												};

		vars.offsetExclamationMark = 0x38C0B;



		//The nose of Morden when he hits the ground after falling from the Hi-Do
		//Starts at pixel ( 188 , 188 )
		vars.colorsMorden = new byte[]			{
													24,		48,		49,		255,
													24,		48,		49,		255,
													115,	146,	148,	255,
													115,	146,	148,	255,
													66,		97,		99,		255,
													165,	219,	255,	255,
													165,	219,	255,	255,
													231,	251,	255,	255,
													57,		97,		132,	255,
													0,		16,		16,		255
												};

		vars.offsetMorden =	0x5E31F;



		//The wall of Rugname we smash into
		//Starts at pixel ( 147 , 35 )
		vars.colorsRugname = new byte[]			{
													115,	113,	107,	255,
													140,	146,	148,	255,
													115,	113,	107,	255,
													90,		89,		82,		255,
													115,	113,	107,	255,
													115,	113,	107,	255,
													90,		89,		82,		255,
													115,	113,	107,	255,
													140,	146,	148,	255,
													115,	113,	107,	255
												};
		
		vars.offsetRugname = 0x11A7B;



		//The foreground after defeating Fake Root, mingled with the second dither pattern of the screen fade
		//The screen shakes at 60Hz here, so we need two values to be sure
		//Starts at pixel ( 286 , 173 )
		vars.colorsFakeRoot1 = new byte[]		{
													0,		0,		0,		255,
													66,		105,	140,	255,
													49,		81,		115,	255,
													49,		81,		115,	255,
													0,		0,		0,		255,
													66,		105,	140,	255,
													66,		105,	140,	255,
													90,		138,	173,	255,
													0,		0,		0,		255,
													90,		138,	173,	255
												};

		vars.colorsFakeRoot2 = new byte[]		{
													0,		0,		0,		255,
													66,		105,	140,	255,
													90,		138,	173,	255,
													66,		105,	140,	255,
													0,		0,		0,		255,
													90,		138,	173,	255,
													90,		138,	173,	255,
													90,		138,	173,	255,
													0,		0,		0,		255,
													66,		105,	140,	255
												};
		
		vars.offsetFakeRoot = 0x56CA7;
		
		
		
		//The rim of Rugname when we exit it just before fighting True Root
		//Starts at pixel ( 36, 0 )
		vars.colorsExit = new byte[]			{
													90,		105,	107,	255,
													255,	251,	255,	255,
													24,		40,		41,		255,
													24,		40,		41,		255,
													24,		40,		41,		255,
													66,		81,		82,		255,
													41,		56,		57,		255,
													41,		56,		57,		255,
													24,		40,		41,		255,
													132,	146,	148,	255
												};

		vars.offsetExit = 0xBF;
		
		
		
		//The background black when True Root dies
		//Starts at pixel ( 36, 0 ) // ( 165 , 0 ) // ( 274 , 181 )
		vars.colorsTrueRoot = new byte[]		{
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255,
													16,		16,		16,		255
												};
		
		vars.offsetTrueRoot1 = 0xBF;

		vars.offsetTrueRoot2 = 0x2C3;

		vars.offsetTrueRoot3 = 0x5AC77;
		
	}
}





exit
{

	//Pause if game is not running
	timer.IsGameTimePaused = true;



	//The pointers and watchers are no longer valid
	vars.pointerScreen = IntPtr.Zero;
	
	vars.watcherScreen = null;

	vars.pointerBossHealth = IntPtr.Zero;

	vars.watcherBossHealth = null;

}





update
{
	
	//Try to find the screen
	//For Kawaks, follow the pointer path
	if(game.ProcessName.Equals("WinKawaks"))
	{
		vars.pointerScreen = new IntPtr(current.pointerScreen);
	}
	
	//For Steam, do a scan
	else
	{

		//If the screen region changed place in memory
		vars.watcherScreen.Update(game);
		
		if (vars.watcherScreen.Changed)
		{
			//print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! screen changed");
			//Void the pointer
			vars.pointerScreen = IntPtr.Zero;

		}

		//print(vars.pointerScreen.ToString());
	
		//If the screen pointer is void
		if (vars.pointerScreen == IntPtr.Zero)
		{
		
			//If the screen scan cooldown has elapsed
			var timeSinceLastScan = Environment.TickCount - vars.prevScanTimeScreen;
	
			if (timeSinceLastScan > 300)
			{
				print("scanning for screen");
				//Scan for the screen
				vars.pointerScreen = vars.FindArray(game, vars.scannerTargetScreen);
			
			
		
				//If the scan was successful
				if (vars.pointerScreen != IntPtr.Zero)
				{
					print("found screen");
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
		
		//Debug print an array
		//print("Rugname");
		
		//vars.PrintArray(vars.ReadArray(game, vars.offsetRugname));

		
	
		//Check if we should start/restart the timer
		vars.restart = vars.MatchArray(vars.ReadArray(game, vars.offsetWaterSplash), vars.colorsWaterSplash);
		
	}
}





reset
{
	
	if (vars.restart)
	{
		vars.splitCounter = 0;
		
		vars.prevSplitTime = -1;
		
		vars.prevScanTimeScreen = -1;

		vars.prevScanTimeBossHealth = -1;
		
		vars.pointerBossHealth = IntPtr.Zero;

		vars.watcherBossHealth = null;

		return true;
	}
}





start
{
	
	if (vars.restart)
	{
		return true;
	}
}





split
{
	
	//Check time since last split, don't split if we already split in the last 20 seconds
	var timeSinceLastSplit = Environment.TickCount - vars.prevSplitTime;
	
	if (vars.prevSplitTime != -1 && timeSinceLastSplit < 20000)
	{
		return false;
	}
	
	
	
	//If we dont know where the screen is, stop
	if (vars.pointerScreen == IntPtr.Zero)
	{
		return false;
	}



	//Missions 1, 2, 3 and 4
	if (vars.splitCounter < 4)
	{
		
		//Split when the exclamation mark from the "Mission Complete !" text is in the right spot
		byte[] pixels = vars.ReadArray(game, vars.offsetExclamationMark);

		if (vars.MatchArray(pixels, vars.colorsExclamationMark))
		{
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}



	//For Morden
	else if (vars.splitCounter == 4)
	{
		
		//Split when Morden's face hits the ground
		byte[] pixels = vars.ReadArray(game, vars.offsetMorden);

		if (vars.MatchArray(pixels, vars.colorsMorden))
		{
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}



	//For Rugname
	else if (vars.splitCounter == 5)
	{
		
		//Split when we hit the inner wall of Rugname
		byte[] pixels = vars.ReadArray(game, vars.offsetRugname);
		
		if (vars.MatchArray(pixels, vars.colorsRugname))
		{
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}



	//For Fake Rootmars
	else if (vars.splitCounter == 6)
	{

		//Split when the fadeout occurs after Fake Root
		//The screen is shaking at that point, so there seems to be 2 possibilities
		byte[] pixels = vars.ReadArray(game, vars.offsetFakeRoot);
		
		if (vars.MatchArray(pixels, vars.colorsFakeRoot1) || vars.MatchArray(pixels, vars.colorsFakeRoot2))
		{
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
			return true;
		}
	}

	

	//Knowing when we get to the last boss
	else if (vars.splitCounter == 7)
	{
		
		//When we exit Rugname
		byte[] pixels = vars.ReadArray(game, vars.offsetExit);
		
		if (vars.MatchArray(pixels, vars.colorsExit))
		{
			
			//Notify
			print("[MS3 AutoSplitter] Last boss starting");

			
			
			//Move to next phase, prevent splitting for 20 seconds (but don't actually split)
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
		}
	}

	

	//For True Rootmars
	else if (vars.splitCounter == 8)
	{
		
		//Split when the background becomes completely black
		//We need to check multiple arrays, because the player or the boss's attacks might be obscuring some of them
		byte[] pixels1 = vars.ReadArray(game, vars.offsetTrueRoot1);

		byte[] pixels2 = vars.ReadArray(game, vars.offsetTrueRoot2);

		byte[] pixels3 = vars.ReadArray(game, vars.offsetTrueRoot3);
		
		if (vars.MatchArray(pixels1, vars.colorsTrueRoot) || vars.MatchArray(pixels2, vars.colorsTrueRoot) || vars.MatchArray(pixels3, vars.colorsTrueRoot))
		{

			//Notify
			print("[MS3 AutoSplitter] Run end");
			
			
			
			//Split
			vars.splitCounter++;
			
			vars.prevSplitTime = Environment.TickCount;
			
			return true;
			
		}
	}
}
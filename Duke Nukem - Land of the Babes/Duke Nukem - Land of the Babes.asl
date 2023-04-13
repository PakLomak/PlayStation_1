state ("mednafen", "1.29.0") { }
state ("EmuHawk", "2.6.3") { }
state ("ePSXe", "2.0.0") { }
state ("duckstation-qt-x64-ReleaseLTCG", "any") { }
state ("duckstation-nogui-x64-ReleaseLTCG", "any") { }
startup
{
    settings.Add("main", false, "AutoSplitter for Duke Nukem - Land of the Babes by PakLomak");
	settings.Add("main3", false, "--https://www.twitch.tv/paklomak", "main");
        // Duckstation Vars
    vars.duckstationProcessNames = new List<string> {
        "duckstation-qt-x64-ReleaseLTCG",
        "duckstation-nogui-x64-ReleaseLTCG",
    };
    vars.duckstation = false;
    vars.duckstationBaseRAMAddressFound  = false;
    vars.duckstationStopwatch = new Stopwatch();
    vars.DUCKSTATION_ADDRESS_SEARCH_INTERVAL = 1000;

    vars.baseRAMAddress = IntPtr.Zero;
}
init
{
    refreshRate = 30;

    var mainModule = modules.First();
    switch (mainModule.ModuleMemorySize) 
    {
    //BizHawk
    case 0x45a000:
        version = "2.6.3";
        vars.baseRAMAddress = modules.Where(x => x.ModuleName == "octoshock.dll").First().BaseAddress + 0x30df80;
        break;
    //epsxe
    case 0x1359000:
        version = "2.0.0";
        vars.baseRAMAddress = mainModule.BaseAddress + 0x81a020;
        break;
    //Mednafen
    case 0x574B000:
        version = "1.29.0";
        vars.baseRAMAddress = mainModule.BaseAddress + 0x1C03E80;
        break;
    // DuckStation or unsupported
    default:
    break;
    }
    // Unfortunately, duckstation doesn't have a static base RAM address,
    // so we'll have to keep track of it in the update block.
    if (vars.duckstationProcessNames.Contains(game.ProcessName)) {
        vars.duckstation = true;
        version = "any";
        vars.baseRAMAddress = IntPtr.Zero;
    }
}
update 
{
    if (version == "") {
        return false;
    }

    if (vars.duckstation) {
        // Find base RAM address in Duckstation by searching its memory pages.
        // Do this periodically (using stopwatch to determine when to search again) 
        // instead of every update to reduce unnecessary computation.
        if (!vars.duckstationBaseRAMAddressFound) {
            if (!vars.duckstationStopwatch.IsRunning || vars.duckstationStopwatch.ElapsedMilliseconds > vars.DUCKSTATION_ADDRESS_SEARCH_INTERVAL) {
                vars.duckstationStopwatch.Start();
                vars.baseRAMAddress = game.MemoryPages(true).Where(p => p.Type == MemPageType.MEM_MAPPED && p.RegionSize == (UIntPtr)0x200000).FirstOrDefault().BaseAddress;
                if (vars.baseRAMAddress == IntPtr.Zero) {
                    vars.duckstationStopwatch.Restart();
                    return false;
                }
                else {
                    vars.duckstationStopwatch.Reset();
                    vars.duckstationBaseRAMAddressFound = true;
                }
            }
            else {
                return false;
            }
        }
        
        // Verify base RAM address is still valid on each update
        IntPtr temp1 = vars.baseRAMAddress;
        IntPtr temp2 = IntPtr.Zero;
        if (!game.ReadPointer(temp1, out temp2)) {
            vars.duckstationBaseRAMAddressFound = false;
            vars.baseRAMAddress = IntPtr.Zero;
            return false;
        }
    }

    // Address assignment has been moved to update block to support Duckstation's
    // changing base RAM address. The performance impact of this should
    // be negligible for non-Duckstation users, 
    // and it reduces code complexity to have it once here.
    
    // States
    vars.igtAddress = vars.baseRAMAddress + 0x0EA164;
    vars.countlvlAddress = vars.baseRAMAddress + 0x1FFF92;
    vars.pauseAddress = vars.baseRAMAddress + 0x070070;

    // Read memory
    current.igt = memory.ReadValue<uint>((IntPtr)vars.igtAddress);
    current.countlvl = memory.ReadValue<uint>((IntPtr)vars.countlvlAddress);
    current.pause = memory.ReadValue<uint>((IntPtr)vars.pauseAddress);
}
start
{
    return (old.igt == 0 && current.igt != 0 && current.countlvl == 0x01);
}
split
{
    if (current.countlvl != 0 && current.countlvl == old.countlvl + 1)   {return true;}
}
isLoading
{
    return true;
}
gameTime
{
    return TimeSpan.FromSeconds(current.igt / 1000.0);
}
/*reset
{
    return (current.pause == 530 && current.countlvl == 0x00 && current.igt == 0x00);
}*/
--[[

Title: Ghostly Ink Mixer V1.05
Description: Mixes ghostly ink, uses whatever necroplasm you set in first slot of inventory. Stops script when out of Materials of any kind.
Date: 1/08/2024
Author: Demoric
Instructions:
    Start at GE
    Set Materials to Preset 1:
        Necroplasm of choice
        13 Ashes
        13 Vial of Water 

Change Log:
V1.01 - Updated offsets.
V1.02 - Updated offsets.
V1.05 - Added Um Bank, added Lummy Chest, added Fort bank chest in workshop. Slightly shorter delays.

IMPORTANT ----SET NECROPLASM TO FIRST SLOT IN INVENTORY----

Report any bugs in discord

]]

local API = require("api")

local ID = {

    Ashes = 592,
    VialofWater = 227,
    lesser = 55599,
    BankerGE = 3418,
    BankerUm = 30301,30298,30302,
    LummyChest = 79036,
    FortChest = 125115,
}

local BankCoords = {
 GEx = 3163,
 GEy = 3484,
 UMx = 1108,
 UMy = 1739,
 Lummyx = 3214,
 Lummyy= 3257,
 Fortx = 3282,
 Forty = 3555
}

local function bank()
    if API.PInArea(BankCoords.GEx,20,BankCoords.GEy,20) then
        API.DoAction_NPC(0x5,1488,{ ID.BankerGE },50);
        API.RandomSleep2(2000,1050,1000)
        if API.BankOpen2() then
            API.KeyboardPress32(0x31,0)
            API.RandomSleep2(150,1050,1000)
            ::continue::
        else
            print("Reattempting Banking")
            bank()
        end
    elseif API.PInArea(BankCoords.UMx,10,BankCoords.UMy,10) then
        API.DoAction_NPC(0x5,1488,{ ID.BankerUm },50);
        API.RandomSleep2(2000,1050,1000)
        if API.BankOpen2() then
            API.KeyboardPress32(0x31,0)
            API.RandomSleep2(150,1050,1000)
            ::continue::
        else
            print("Reattempting Banking")
            bank()
        end
    elseif API.PInArea(BankCoords.Lummyx,10,BankCoords.Lummyy,10) then
        API.DoAction_Object1(0x2e,80,{ ID.LummyChest },50)
        API.RandomSleep2(2000,1050,1000)
        if API.BankOpen2() then
            API.KeyboardPress32(0x31,0)
            API.RandomSleep2(150,1050,1000)
            ::continue::
        else
            print("Reattempting Banking")
            bank()
        end
    elseif API.PInArea(BankCoords.Fortx,10,BankCoords.Forty,10) then
        API.DoAction_Object1(0x2e,80,{ ID.FortChest },50)
        API.RandomSleep2(2000,1050,1000)
        if API.BankOpen2() then
            API.KeyboardPress32(0x31,0)
            API.RandomSleep2(2000,1050,1000)
            ::continue::
        else
            print("Reattempting Banking")
            bank()
        end
    else
        print("go to GE, Um Bank, Lum Chest, or Fort Chest")
        API.Write_LoopyLoop(false)
    end
    ::continue::
    API.RandomSleep2(300,500,500)
end

API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do

    if API.InvItemcount_1(ID.Ashes) == 0 and API.InvItemcount_1(ID.VialofWater) == 0 then
        print("Getting Materials")
        bank()
    end

    Necroplasm = API.ScanForInterfaceTest2Get(false,{ { 1473,0,-1,-1,0 }, { 1473,2,-1,0,0 }, { 1473,5,-1,2,0 }, { 1473,5,0,5,0 } }) [1]
    API.RandomSleep2(1000,500,1000)
    if (Necroplasm.itemid1 > 0 and Necroplasm.itemid1_size <= 19) or (Necroplasm.itemid1 < 0) then
        if API.InvItemcount_1(ID.Ashes) >=1 and API.InvItemcount_1(ID.VialofWater) >= 1 then
            print("Getting materials")
            bank()
        else
            print("No more NecroPlasm, Stopping Script")
            API.Write_LoopyLoop(false)
        end
    end

    if API.InvItemcount_1(ID.Ashes) >=1 and API.InvItemcount_1(ID.VialofWater) >= 1 then
        Necroplasm = API.ScanForInterfaceTest2Get(false,{ { 1473,0,-1,-1,0 }, { 1473,2,-1,0,0 }, { 1473,5,-1,2,0 }, { 1473,5,0,5,0 } }) [1]
        API.RandomSleep2(1000,500,1000)
        if Necroplasm.itemid1 > 0 and Necroplasm.itemid1_size >= 20 then
            print("Mixing Ink")
            API.DoAction_Interface(0x3e,0xd92f,1,1473,5,0,3808)
            API.RandomSleep2(1000,1050,1500)
            API.KeyboardPress32(0x20,0)
            API.RandomSleep2(16000,1000,1050)
        else
            print("No more NecroPlasm, Stopping Script")
            API.Write_LoopyLoop(false)
        end
    elseif API.InvItemcount_1(ID.Ashes) == 0 and API.InvItemcount_1(ID.VialofWater) >= 1 then
        print("No more ashes, stopping Script")
        API.Write_LoopyLoop(false)
    elseif API.InvItemcount_1(ID.Ashes) >= 1 and API.InvItemcount_1(ID.VialofWater) == 0 then
        print("No more vial of water, stopping Script")
        API.Write_LoopyLoop(false)
    end
end

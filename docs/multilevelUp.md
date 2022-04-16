### Multi Level Up Feature

* The contract has all **cumulative** level up costs starting from level 2 to level 100, and it simple substracts the FLY cost of the current level from the target level. The difference is multiplied by 10^17 to scale up accordingly. 
* The cumulative level up costs are calculated by summing up each level cost from the original contract. We had a better approach for this which utilized harmonic numbers but the difference between the naive sum up and this approach was more than 10 % for some intervals and the code was more complex so we decided to skip it. 
* After the cumulative level up costs are calculated, all of them are packed into uint256's using uint16's, which decreased the total cost of storage. In addition to that, since those values are immutable, there will be no `sload` which will further reduce the cost. 
* You can see the cumulative leveling costs and the function that was used to create the bit packing down below. 
* The test file tests for all possible combinations (starting level from 2 to 99) with an arbitrary number of levels (from 1 to 99) are tested.


```
        Cumulative leveling costs

		lookupTable[2] =     10;
        lookupTable[3] =     25;
        lookupTable[4] =     45;
        lookupTable[5] =     70;
        lookupTable[6] =    100;
        lookupTable[7] =    135;
        lookupTable[8] =    175;
        lookupTable[9] =    220;
        lookupTable[10] =   270;
        lookupTable[11] =   325;
        lookupTable[12] =   385;
        lookupTable[13] =   450;
        lookupTable[14] =   520;
        lookupTable[15] =   595;
        lookupTable[16] =   675;
        lookupTable[17] =   760;
        lookupTable[18] =   850;
        lookupTable[19] =   945;
        lookupTable[20] =  1045;
        lookupTable[21] =  1145;
        lookupTable[22] =  1255;
        lookupTable[23] =  1375;
        lookupTable[24] =  1495;
        lookupTable[25] =  1625;
        lookupTable[26] =  1765;
        lookupTable[27] =  1915;
        lookupTable[28] =  2065;
        lookupTable[29] =  2225;
        lookupTable[30] =  2395;
        lookupTable[31] =  2575;
        lookupTable[32] =  2765;
        lookupTable[33] =  2965;
        lookupTable[34] =  3175;
        lookupTable[35] =  3385;
        lookupTable[36] =  3605;
        lookupTable[37] =  3835;
        lookupTable[38] =  4075;
        lookupTable[39] =  4325;
        lookupTable[40] =  4585;
        lookupTable[41] =  4855;
        lookupTable[42] =  5135;
        lookupTable[43] =  5425;
        lookupTable[44] =  5725;
        lookupTable[45] =  6035;
        lookupTable[46] =  6355;
        lookupTable[47] =  6685;
        lookupTable[48] =  7025;
        lookupTable[49] =  7375;
        lookupTable[50] =  7735;
        lookupTable[51] =  8105;
        lookupTable[52] =  8485;
        lookupTable[53] =  8875;
        lookupTable[54] =  9275;
        lookupTable[55] =  9685;
        lookupTable[56] = 10115;
        lookupTable[57] = 10555;
        lookupTable[58] = 11005;
        lookupTable[59] = 11465;
        lookupTable[60] = 11935;
        lookupTable[61] = 12415;
        lookupTable[62] = 12905;
        lookupTable[63] = 13405;
        lookupTable[64] = 13925;
        lookupTable[65] = 14455;
        lookupTable[66] = 14995;
        lookupTable[67] = 15545;
        lookupTable[68] = 16105;
        lookupTable[69] = 16685;
        lookupTable[70] = 17275;
        lookupTable[71] = 17875;
        lookupTable[72] = 18485;
        lookupTable[73] = 19105;
        lookupTable[74] = 19745;
        lookupTable[75] = 20395;
        lookupTable[76] = 21055;
        lookupTable[77] = 21725;
        lookupTable[78] = 22415;
        lookupTable[79] = 23115;
        lookupTable[80] = 23825;
        lookupTable[81] = 24555;
        lookupTable[82] = 25295;
        lookupTable[83] = 26045;
        lookupTable[84] = 26815;
        lookupTable[85] = 27595;
        lookupTable[86] = 28385;
        lookupTable[87] = 29195;
        lookupTable[88] = 30015;
        lookupTable[89] = 30845;
        lookupTable[90] = 31695;
        lookupTable[91] = 32555;
        lookupTable[92] = 33425;
        lookupTable[93] = 34315;
        lookupTable[94] = 35215;
        lookupTable[95] = 36125;
        lookupTable[96] = 37055;
        lookupTable[97] = 37995;
        lookupTable[98] = 38955;
        lookupTable[99] = 39925;
        lookupTable[100] =40905;

```

```
    function createBitMappings() public returns (uint) { // for the last 96, 97, 98, 99, 100 and the unused rest.
        uint[] memory lookupTable = new uint[](16);
        lookupTable[0] = 37055;
        lookupTable[1] = 37995;
        lookupTable[2] = 38955;
        lookupTable[3] = 39925;
        lookupTable[4]  =40905;
        lookupTable[5] = 0;
        lookupTable[6] = 0;
        lookupTable[7] = 0;
        lookupTable[8] = 0;
        lookupTable[9] = 0;
        lookupTable[10]= 0;
        lookupTable[11]= 0;
        lookupTable[12]= 0;
        lookupTable[13]= 0;
        lookupTable[14]= 0;
        lookupTable[15]= 0;
        uint256 x;
        for (uint256 index = 0; index < 16; index++) {
            uint temp = lookupTable[index];
            temp = temp << (16 * index);
            x = (x | temp);
            
        }
        emit log_uint(x);
        return x;
    }
```


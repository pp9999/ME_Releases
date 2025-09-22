local API = require("api")
local afk = os.time()
local islands = {}

islands[1] = {}
islands[2] = {}
islands[3] = {}

-- Map 1 (Lower):
islands[1][1] = {
    {x = 3997, y = 6092}, {x = 3987, y = 6096}, {x = 3985, y = 6105},
    {x = 3979, y = 6111}, {x = 3983, y = 6118}, {x = 3993, y = 6119},
    {x = 4003, y = 6122}, {x = 4006, y = 6119}, {x = 4007, y = 6109},
    {x = 4010, y = 6102}, {x = 4004, y = 6095}
}
islands[1][2] = {
    {x = 3983, y = 6130}, {x = 3995, y = 6129}, {x = 3992, y = 6120}, {x = 3985, y = 6118}
}
islands[1][3] = {
    {x = 3988, y = 6131}, {x = 3990, y = 6139}, {x = 3999, y = 6141}, {x = 4000, y = 6129}
}
islands[1][4] = {
    {x = 4002, y = 6139}, {x = 4019, y = 6138}, {x = 4019, y = 6122}, {x = 4010, y = 6119}, {x = 4001, y = 6123}
}
islands[1][5] = {
    {x = 4020, y = 6126}, {x = 4020, y = 6138}, {x = 4034, y = 6139}, {x = 4032, y = 6125}
}
islands[1][6] = {
    {x = 4007, y = 6109}, {x = 4007, y = 6118}, {x = 4016, y = 6118},
    {x = 4016, y = 6111}, {x = 4013, y = 6109}
}
islands[1][7] = {
    {x = 3974, y = 6083}, {x = 3974, y = 6094}, {x = 3986, y = 6096},
    {x = 3991, y = 6092}, {x = 3991, y = 6088}, {x = 3985, y = 6083}
}
islands[1][8] = {
    {x = 4011, y = 6099}, {x = 4011, y = 6108}, {x = 4020, y = 6115},
    {x = 4029, y = 6113}, {x = 4028, y = 6098}, {x = 4017, y = 6097}
}
islands[1][9] = {
    {x = 4019, y = 6115}, {x = 4019, y = 6124}, {x = 4032, y = 6124},
    {x = 4032, y = 6115}
}
islands[1][10] = {
    {x = 3993, y = 6067}, {x = 3993, y = 6080}, {x = 3989, y = 6083},
    {x = 3991, y = 6091}, {x = 4012, y = 6096}, {x = 4010, y = 6075},
    {x = 4003, y = 6067}
}
islands[1][11] = {
    {x = 3980, y = 6068}, {x = 3980, y = 6080}, {x = 3988, y = 6084},
    {x = 3993, y = 6076}, {x = 3992, y = 6067}, {x = 3986, y = 6066}
}
islands[1][12] = {
    {x = 3988, y = 6057}, {x = 3984, y = 6057}, {x = 3975, y = 6063},
    {x = 3977, y = 6068}, {x = 3985, y = 6067}, {x = 3992, y = 6063},
    {x = 3991, y = 6059}
}
islands[1][13] = {
    {x = 4029, y = 6077}, {x = 4012, y = 6079}, {x = 4012, y = 6095}, {x = 4029, y = 6095}
}
islands[1][14] = {
    {x = 4012, y = 6065}, {x = 4012, y = 6078}, {x = 4029, y = 6076}, {x = 4029, y = 6064}
}
islands[1][15] = {
    {x = 4030, y = 6052}, {x = 4017, y = 6052}, {x = 4013, y = 6057}, {x = 4013, y = 6064}, {x = 4030, y = 6064}
}
islands[1][16] = {
    {x = 4009, y = 6040}, {x = 3995, y = 6041}, {x = 3988, y = 6050},
    {x = 3988, y = 6056}, {x = 3997, y = 6065}, {x = 4007, y = 6069},
    {x = 4013, y = 6061}, {x = 4014, y = 6057}, {x = 4017, y = 6051},
    {x = 4013, y = 6044}
}
islands[1][17] = {
    {x = 3991, y = 6021}, {x = 3991, y = 6040}, {x = 4005, y = 6040}, {x = 4005, y = 6021}
}
islands[1][18] = {
    {x = 4007, y = 6025}, {x = 4007, y = 6034}, {x = 4017, y = 6034}, {x = 4018, y = 6024}
}
islands[1][19] = {
    {x = 4025, y = 6031}, {x = 4014, y = 6035}, {x = 4014, y = 6046}, 
    {x = 4021, y = 6051}, {x = 4031, y = 6045}, {x = 4031, y = 6033}
}
islands[1][20] = {
    {x = 4020, y = 6018}, {x = 4020, y = 6029}, {x = 4031, y = 6029}, {x = 4031, y = 6018}
}
islands[1][21] = {
    {x = 4004, y = 6015}, {x = 4004, y = 6022}, {x = 4011, y = 6025}, {x = 4017, y = 6024}, {x = 4016, y = 6015}
}
islands[1][22] = {
    {x = 3980, y = 6036}, {x = 3980, y = 6047}, {x = 3987, y = 6049}, {x = 3991, y = 6047}, {x = 3990, y = 6038}
}
islands[1][23] = {
    {x = 3979, y = 6021}, {x = 3979, y = 6035}, {x = 3990, y = 6035}, {x = 3990, y = 6022}
}
islands[1][24] = {
    {x = 3961, y = 6018}, {x = 3961, y = 6028}, {x = 3977, y = 6032}, {x = 3976, y = 6018}
}
islands[1][25] = {
    {x = 3955, y = 6044}, {x = 3972, y = 6044}, {x = 3972, y = 6031}, {x = 3957, y = 6030}
}
islands[1][26] = {
    {x = 3953, y = 6045}, {x = 3953, y = 6057}, {x = 3965, y = 6067},
    {x = 3987, y = 6055}, {x = 3986, y = 6049}, {x = 3977, y = 6044}
}
islands[1][27] = {
    {x = 3953, y = 6030}, {x = 3937, y = 6031}, {x = 3934, y = 6037},
    {x = 3937, y = 6050}, {x = 3952, y = 6049}, {x = 3954, y = 6044}
}
islands[1][28] = {
    {x = 3957, y = 6016}, {x = 3942, y = 6016}, {x = 3942, y = 6028},
    {x = 3957, y = 6029}
}
islands[1][29] = {
    {x = 3928, y = 6020}, {x = 3928, y = 6032}, {x = 3937, y = 6031},
    {x = 3940, y = 6025}, {x = 3938, y = 6021}
}
islands[1][30] = {
    {x = 3919, y = 6030}, {x = 3911, y = 6042}, {x = 3920, y = 6051},
    {x = 3932, y = 6045}, {x = 3933, y = 6035}
}
islands[1][31] = {
    {x = 3913, y = 6016}, {x = 3913, y = 6026}, {x = 3926, y = 6029},
    {x = 3927, y = 6018}
}
islands[1][32] = {
    {x = 3904, y = 6027}, {x = 3904, y = 6040}, {x = 3913, y = 6040},
    {x = 3914, y = 6027}
}
islands[1][33] = {
    {x = 3919, y = 6052}, {x = 3919, y = 6063}, {x = 3929, y = 6067},
    {x = 3935, y = 6055}, {x = 3933, y = 6049}
}
islands[1][34] = {
    {x = 3906, y = 6052}, {x = 3906, y = 6063}, {x = 3917, y = 6063},
    {x = 3917, y = 6052}
}
islands[1][35] = {
    {x = 3944, y = 6051}, {x = 3935, y = 6054}, {x = 3932, y = 6063},
    {x = 3930, y = 6090}, {x = 3949, y = 6091}, {x = 3952, y = 6084},
    {x = 3961, y = 6074}, {x = 3955, y = 6061}
}
islands[1][36] = {
    {x = 3910, y = 6064}, {x = 3910, y = 6074}, {x = 3926, y = 6080},
    {x = 3930, y = 6077}, {x = 3928, y = 6070}, {x = 3918, y = 6064}
}
islands[1][37] = {
    {x = 3908, y = 6077}, {x = 3908, y = 6088}, {x = 3920, y = 6087},
    {x = 3922, y = 6080}, {x = 3918, y = 6076}
}
islands[1][38] = {
    {x = 3928, y = 6086}, {x = 3910, y = 6094}, {x = 3918, y = 6104},
    {x = 3928, y = 6104}
}
islands[1][39] = {
    {x = 3902, y = 6097}, {x = 3902, y = 6111}, {x = 3914, y = 6111},
    {x = 3912, y = 6098}
}
islands[1][40] = {
    {x = 3904, y = 6115}, {x = 3904, y = 6128}, {x = 3917, y = 6128},
    {x = 3917, y = 6115}
}
islands[1][41] = {
    {x = 3905, y = 6131}, {x = 3905, y = 6142}, {x = 3916, y = 6142},
    {x = 3915, y = 6130}
}
islands[1][42] = {
    {x = 3915, y = 6106}, {x = 3915, y = 6116}, {x = 3926, y = 6118},
    {x = 3931, y = 6108}, {x = 3923, y = 6105}
}
islands[1][43] = {
    {x = 3933, y = 6107}, {x = 3922, y = 6124}, {x = 3932, y = 6134},
    {x = 3942, y = 6126}, {x = 3942, y = 6113}
}
islands[1][44] = {
    {x = 3916, y = 6128}, {x = 3916, y = 6139}, {x = 3925, y = 6139}, {x = 3925, y = 6129}
}
islands[1][45] = {
    {x = 3926, y = 6134}, {x = 3926, y = 6144}, {x = 3936, y = 6143}, {x = 3937, y = 6134}
}
islands[1][46] = {
    {x = 3930, y = 6092}, {x = 3930, y = 6103}, {x = 3947, y = 6114},
    {x = 3950, y = 6108}, {x = 3950, y = 6100}, {x = 3943, y = 6090}
}
islands[1][47] = {
    {x = 3947, y = 6117}, {x = 3939, y = 6128}, {x = 3947, y = 6138},
    {x = 3959, y = 6129}, {x = 3958, y = 6121}
}
islands[1][48] = {
    {x = 3959, y = 6134}, {x = 3948, y = 6140}, {x = 3949, y = 6147},
    {x = 3966, y = 6146}, {x = 3966, y = 6140}
}
islands[1][49] = {
    {x = 3974, y = 6144}, {x = 3985, y = 6144}, {x = 3985, y = 6134},
    {x = 3975, y = 6134}
}
islands[1][50] = {
    {x = 3961, y = 6123}, {x = 3961, y = 6134}, {x = 3970, y = 6138},
    {x = 3979, y = 6132}, {x = 3983, y = 6122}, {x = 3979, y = 6114},
    {x = 3969, y = 6115}
}

-- Map 2 (Middle):
islands[2][1] = {
    {x = 4139, y = 6108}, {x = 4153, y = 6108}, {x = 4153, y = 6113}, {x = 4165, y = 6113}, {x = 4165, y = 6102},
    {x = 4171, y = 6097}, {x = 4171, y = 6085}, {x = 4151, y = 6085}, {x = 4151, y = 6095}, {x = 4139, y = 6095}
}
islands[2][2] = {
    {x = 4172, y = 6100}, {x = 4190, y = 6100}, {x = 4190, y = 6082}, {x = 4171, y = 6084}
}
islands[2][3] = {
    {x = 4157, y = 6049}, {x = 4157, y = 6084}, {x = 4190, y = 6084}, {x = 4190, y = 6058}, {x = 4178, y = 6049}
}
islands[2][4] = {
    {x = 4139, y = 6044}, {x = 4130, y = 6055}, {x = 4130, y = 6065}, 
    {x = 4143, y = 6068}, {x = 4151, y = 6075}, {x = 4159, y = 6075}, 
    {x = 4150, y = 6047}
}
islands[2][5] = {
    {x = 4131, y = 6065}, {x = 4122, y = 6075}, {x = 4123, y = 6092}, 
    {x = 4142, y = 6096}, {x = 4155, y = 6080}, {x = 4142, y = 6067}
}
islands[2][6] = {
    {x = 4130, y = 6092}, {x = 4122, y = 6093}, {x = 4119, y = 6097}, 
    {x = 4119, y = 6109}, {x = 4130, y = 6115}, {x = 4138, y = 6108}, 
    {x = 4139, y = 6097}
}
islands[2][7] = {
    {x = 4103, y = 6107}, {x = 4103, y = 6118}, {x = 4123, y = 6132}, 
    {x = 4130, y = 6127}, {x = 4129, y = 6113}, {x = 4117, y = 6107}
}
islands[2][8] = {
    {x = 4104, y = 6106}, {x = 4118, y = 6106}, {x = 4118, y = 6096}, {x = 4105, y = 6093}
}
islands[2][9] = {
    {x = 4094, y = 6120}, {x = 4094, y = 6138}, {x = 4104, y = 6137}, {x = 4110, y = 6120}
}
islands[2][10] = {
    {x = 4111, y = 6124}, {x = 4100, y = 6141}, {x = 4121, y = 6144}, {x = 4118, y = 6127}
}
islands[2][11] = {
    {x = 4137, y = 6109}, {x = 4129, y = 6121}, {x = 4129, y = 6129}, {x = 4150, y = 6127}, {x = 4153, y = 6112}
}
islands[2][12] = {
    {x = 4141, y = 6130}, {x = 4130, y = 6130}, {x = 4129, y = 6141}, {x = 4142, y = 6143}
}
islands[2][13] = {
    {x = 4156, y = 6128}, {x = 4145, y = 6128}, {x = 4145, y = 6142}, {x = 4156, y = 6142}
}
islands[2][14] = {
    {x = 4160, y = 6115}, {x = 4153, y = 6115}, {x = 4153, y = 6127}, {x = 4163, y = 6134}, 
    {x = 4170, y = 6131}, {x = 4166, y = 6118}
}
islands[2][15] = {
    {x = 4175, y = 6101}, {x = 4166, y = 6105}, {x = 4165, y = 6120}, {x = 4176, y = 6122}, 
    {x = 4183, y = 6105}
}
islands[2][16] = {
    {x = 4187, y = 6120}, {x = 4177, y = 6123}, {x = 4174, y = 6132}, {x = 4182, y = 6137}, 
    {x = 4190, y = 6134}, {x = 4192, y = 6121}
}
islands[2][17] = {
    {x = 4168, y = 6132}, {x = 4168, y = 6144}, {x = 4181, y = 6144}, {x = 4175, y = 6133}
}
islands[2][18] = {
    {x = 4196, y = 6132}, {x = 4187, y = 6136}, {x = 4189, y = 6144}, {x = 4203, y = 6143}, {x = 4200, y = 6133}
}
islands[2][19] = {
    {x = 4193, y = 6119}, {x = 4193, y = 6131}, {x = 4204, y = 6131}, {x = 4204, y = 6119}
}
islands[2][20] = {
    {x = 4205, y = 6123}, {x = 4205, y = 6138}, {x = 4218, y = 6138}, {x = 4217, y = 6123}
}
islands[2][21] = {
    {x = 4201, y = 6110}, {x = 4201, y = 6120}, {x = 4220, y = 6120}, {x = 4220, y = 6102}, {x = 4210, y = 6103}
}
islands[2][22] = {
    {x = 4182, y = 6105}, {x = 4182, y = 6118}, {x = 4192, y = 6118}, {x = 4191, y = 6105}
}
islands[2][23] = {
    {x = 4191, y = 6085}, {x = 4191, y = 6109}, {x = 4205, y = 6109}, {x = 4205, y = 6085}
}
islands[2][24] = {
    {x = 4216, y = 6072}, {x = 4202, y = 6080}, {x = 4208, y = 6090}, {x = 4217, y = 6086}
}
islands[2][25] = {
    {x = 4207, y = 6089}, {x = 4207, y = 6098}, {x = 4220, y = 6097}, {x = 4217, y = 6087}
}
islands[2][26] = {
    {x = 4209, y = 6056}, {x = 4196, y = 6058}, {x = 4190, y = 6075}, {x = 4198, y = 6081}, {x = 4209, y = 6072}
}
islands[2][27] = {
    {x = 4223, y = 6052}, {x = 4210, y = 6058}, {x = 4212, y = 6067}, {x = 4223, y = 6067}
}
islands[2][28] = {
    {x = 4208, y = 6042}, {x = 4208, y = 6053}, {x = 4221, y = 6052}, {x = 4221, y = 6042}
}
islands[2][29] = {
    {x = 4198, y = 6036}, {x = 4189, y = 6036}, {x = 4184, y = 6052}, 
    {x = 4193, y = 6060}, {x = 4206, y = 6049}, {x = 4203, y = 6041}
}
islands[2][30] = {
    {x = 4199, y = 6023}, {x = 4199, y = 6035}, {x = 4210, y = 6042}, 
    {x = 4215, y = 6035}, {x = 4209, y = 6023}
}
islands[2][31] = {
    {x = 4208, y = 6017}, {x = 4219, y = 6033}, {x = 4223, y = 6016}
}
islands[2][32] = {
    {x = 4182, y = 6023}, {x = 4191, y = 6038}, {x = 4199, y = 6023}
}
islands[2][33] = {
    {x = 4176, y = 6030}, {x = 4166, y = 6035}, {x = 4166, y = 6047},
    {x = 4180, y = 6051}, {x = 4188, y = 6038}, {x = 4182, y = 6031}
}
islands[2][34] = {
    {x = 4172, y = 6022}, {x = 4157, y = 6022}, {x = 4157, y = 6035}, {x = 4171, y = 6034}
}
islands[2][35] = {
    {x = 4154, y = 6036}, {x = 4147, y = 6038}, {x = 4148, y = 6047}, {x = 4163, y = 6050}, {x = 4165, y = 6036}
}
islands[2][36] = {
    {x = 4131, y = 6032}, {x = 4138, y = 6041}, {x = 4148, y = 6037}, {x = 4156, y = 6036}, 
    {x = 4156, y = 6024}, {x = 4139, y = 6024}
}
islands[2][37] = {
    {x = 4153, y = 6014}, {x = 4139, y = 6014}, {x = 4139, y = 6024}, {x = 4153, y = 6024}
}
islands[2][38] = {
    {x = 4125, y = 6035}, {x = 4120, y = 6035}, {x = 4117, y = 6039}, {x = 4117, y = 6047},
    {x = 4130, y = 6055}, {x = 4136, y = 6051}, {x = 4133, y = 6037}
}
islands[2][39] = {
    {x = 4135, y = 6019}, {x = 4121, y = 6022}, {x = 4121, y = 6033}, 
    {x = 4130, y = 6033}, {x = 4136, y = 6028}
}
islands[2][40] = {
    {x = 4113, y = 6029}, {x = 4097, y = 6029}, {x = 4097, y = 6047}, 
    {x = 4115, y = 6048}, {x = 4117, y = 6039}, {x = 4119, y = 6033}
}
islands[2][41] = {
    {x = 4110, y = 6018}, {x = 4110, y = 6029}, {x = 4118, y = 6029}, {x = 4120, y = 6019}
}
islands[2][42] = {
    {x = 4109, y = 6016}, {x = 4096, y = 6016}, {x = 4096, y = 6026}, {x = 4109, y = 6027}
}
islands[2][43] = {
    {x = 4103, y = 6050}, {x = 4103, y = 6060}, {x = 4110, y = 6063}, {x = 4115, y = 6063}, {x = 4115, y = 6050}
}
islands[2][44] = {
    {x = 4119, y = 6053}, {x = 4111, y = 6066}, {x = 4113, y = 6075},
    {x = 4123, y = 6074}, {x = 4130, y = 6064}, {x = 4128, y = 6054}
}
islands[2][45] = {
    {x = 4103, y = 6061}, {x = 4095, y = 6061}, {x = 4095, y = 6070},
    {x = 4106, y = 6074}, {x = 4110, y = 6067}, {x = 4106, y = 6062}
}
islands[2][46] = {
    {x = 4099, y = 6075}, {x = 4099, y = 6083}, {x = 4117, y = 6096},
    {x = 4123, y = 6091}, {x = 4122, y = 6081}, {x = 4109, y = 6076}
}

-- Map 3 (upper):
islands[3][1] = {
    {x = 4287, y = 6019}, {x = 4287, y = 6046}, {x = 4297, y = 6046},
    {x = 4314, y = 6039}, {x = 4313, y = 6019}
}
islands[3][2] = {
    {x = 4308, y = 6043}, {x = 4302, y = 6043}, {x = 4293, y = 6051},
    {x = 4295, y = 6063}, {x = 4302, y = 6069}, {x = 4307, y = 6068},
    {x = 4309, y = 6062}, {x = 4307, y = 6056}, {x = 4313, y = 6048}
}
islands[3][3] = {
    {x = 4287, y = 6065}, {x = 4292, y = 6094}, {x = 4306, y = 6094},
    {x = 4308, y = 6083}, {x = 4310, y = 6072}, {x = 4301, y = 6067}
}
islands[3][4] = {
    {x = 4302, y = 6096}, {x = 4296, y = 6096}, {x = 4288, y = 6106},
    {x = 4288, y = 6136}, {x = 4307, y = 6136}, {x = 4314, y = 6123},
    {x = 4317, y = 6113}
}
islands[3][5] = {
    {x = 4324, y = 6115}, {x = 4317, y = 6119}, {x = 4315, y = 6126},
    {x = 4309, y = 6131}, {x = 4319, y = 6145}, {x = 4328, y = 6144},
    {x = 4333, y = 6135}, {x = 4331, y = 6128}, {x = 4332, y = 6122},
    {x = 4330, y = 6118}
}
islands[3][6] = {
    {x = 4333, y = 6126}, {x = 4333, y = 6137}, {x = 4342, y = 6145},
    {x = 4370, y = 6145}, {x = 4374, y = 6134}, {x = 4373, y = 6129},
    {x = 4365, y = 6124}, {x = 4352, y = 6125}, {x = 4347, y = 6128},
    {x = 4340, y = 6125}
}
islands[3][7] = {
    {x = 4375, y = 6133}, {x = 4375, y = 6144}, {x = 4386, y = 6144},
    {x = 4390, y = 6139}, {x = 4397, y = 6146}, {x = 4408, y = 6142},
    {x = 4408, y = 6128}, {x = 4387, y = 6122}
}
islands[3][8] = {
    {x = 4391, y = 6114}, {x = 4391, y = 6119}, {x = 4401, y = 6122},
    {x = 4408, y = 6127}, {x = 4417, y = 6122}, {x = 4415, y = 6097},
    {x = 4399, y = 6097}
}
islands[3][9] = {
    {x = 4390, y = 6095}, {x = 4411, y = 6095}, {x = 4417, y = 6080},
    {x = 4416, y = 6070}, {x = 4405, y = 6055}, {x = 4386, y = 6053},
    {x = 4388, y = 6082}, {x = 4391, y = 6085}, {x = 4389, y = 6093}
}
islands[3][10] = {
    {x = 4396, y = 6054}, {x = 4405, y = 6054}, {x = 4412, y = 6046},
    {x = 4415, y = 6034}, {x = 4399, y = 6023}, {x = 4388, y = 6024},
    {x = 4382, y = 6031}, {x = 4387, y = 6040}, {x = 4389, y = 6048}
}
islands[3][11] = {
    {x = 4346, y = 6017}, {x = 4347, y = 6035}, {x = 4375, y = 6035},
    {x = 4386, y = 6023}, {x = 4383, y = 6017}, {x = 4363, y = 6015}
}
islands[3][12] = {
    {x = 4316, y = 6038}, {x = 4342, y = 6038}, {x = 4347, y = 6025},
    {x = 4342, y = 6016}, {x = 4317, y = 6021}
}
islands[3][13] = {
    {x = 4322, y = 6041}, {x = 4322, y = 6048}, {x = 4330, y = 6056},
    {x = 4356, y = 6056}, {x = 4364, y = 6050}, {x = 4365, y = 6037},
    {x = 4335, y = 6039}, {x = 4322, y = 6038}
}
islands[3][14] = {
    {x = 4309, y = 6061}, {x = 4323, y = 6061}, {x = 4326, y = 6055},
    {x = 4322, y = 6049}, {x = 4313, y = 6049}, {x = 4308, y = 6054}
}
islands[3][15] = {
    {x = 4318, y = 6067}, {x = 4327, y = 6073}, {x = 4333, y = 6069},
    {x = 4333, y = 6066}, {x = 4327, y = 6060}
}
islands[3][16] = {
    {x = 4329, y = 6057}, {x = 4329, y = 6061}, {x = 4335, y = 6069},
    {x = 4343, y = 6068}, {x = 4343, y = 6057}
}
islands[3][17] = {
    {x = 4329, y = 6072}, {x = 4329, y = 6081}, {x = 4346, y = 6081},
    {x = 4345, y = 6069}, {x = 4334, y = 6070}
}
islands[3][18] = {
    {x = 4308, y = 6088}, {x = 4317, y = 6088}, {x = 4327, y = 6080},
    {x = 4327, y = 6071}, {x = 4317, y = 6069}, {x = 4308, y = 6080}
}
islands[3][19] = {
    {x = 4312, y = 6090}, {x = 4312, y = 6097}, {x = 4329, y = 6095},
    {x = 4329, y = 6086}, {x = 4321, y = 6085}
}
islands[3][20] = {
    {x = 4312, y = 6100}, {x = 4321, y = 6113}, {x = 4328, y = 6115},
    {x = 4336, y = 6124}, {x = 4346, y = 6127}, {x = 4351, y = 6123},
    {x = 4353, y = 6109}, {x = 4353, y = 6105}, {x = 4338, y = 6105},
    {x = 4328, y = 6096}, {x = 4320, y = 6096}
}
islands[3][21] = {
    {x = 4332, y = 6087}, {x = 4332, y = 6097}, {x = 4341, y = 6101}, {x = 4344, y = 6087}
}
islands[3][22] = {
    {x = 4342, y = 6102}, {x = 4355, y = 6102}, {x = 4352, y = 6088}, {x = 4343, y = 6088}
}
islands[3][23] = {
    {x = 4353, y = 6111}, {x = 4353, y = 6122}, {x = 4365, y = 6122}, {x = 4365, y = 6111}
}
islands[3][24] = {
    {x = 4365, y = 6121}, {x = 4374, y = 6130}, {x = 4384, y = 6123},
    {x = 4384, y = 6114}, {x = 4378, y = 6109}, {x = 4368, y = 6109}
}
islands[3][25] = {
    {x = 4357, y = 6100}, {x = 4357, y = 6110}, {x = 4369, y = 6110},
    {x = 4370, y = 6107}, {x = 4371, y = 6099}, {x = 4364, y = 6098}
}
islands[3][26] = {
    {x = 4371, y = 6100}, {x = 4371, y = 6107}, {x = 4378, y = 6108},
    {x = 4385, y = 6114}, {x = 4392, y = 6112}, {x = 4392, y = 6102},
    {x = 4386, y = 6097}, {x = 4377, y = 6094}
}
islands[3][27] = {
    {x = 4359, y = 6082}, {x = 4359, y = 6096}, {x = 4371, y = 6096},
    {x = 4374, y = 6090}
}
islands[3][28] = {
    {x = 4378, y = 6087}, {x = 4378, y = 6094}, {x = 4389, y = 6094},
    {x = 4390, y = 6083}
}
islands[3][29] = {
    {x = 4379, y = 6069}, {x = 4368, y = 6076}, {x = 4374, y = 6087},
    {x = 4379, y = 6087}, {x = 4387, y = 6083}, {x = 4386, y = 6070}
}
islands[3][30] = {
    {x = 4361, y = 6061}, {x = 4361, y = 6072}, {x = 4372, y = 6072},
    {x = 4375, y = 6067}, {x = 4374, y = 6060}
}
islands[3][31] = {
    {x = 4374, y = 6053}, {x = 4374, y = 6064}, {x = 4386, y = 6064},
    {x = 4386, y = 6053}
}
islands[3][32] = {
    {x = 4347, y = 6058}, {x = 4347, y = 6071}, {x = 4360, y = 6071},
    {x = 4360, y = 6058}
}
islands[3][33] = {
    {x = 4373, y = 6049}, {x = 4386, y = 6049}, {x = 4386, y = 6038},
    {x = 4381, y = 6031}, {x = 4374, y = 6033}
}
-- Debug flag
local DEBUG = true
local function debugPrint(message)
    if DEBUG then
        print("DEBUG: " .. message)
    end
end

local function sleepUntil(conditionFunc, timeout, message, callback)
    timeout = timeout or 10  -- default timeout value
    message = message or "condition"  -- default message value
    debugPrint("sleepUntil started for " .. message .. " with timeout " .. tostring(timeout))
    local startTime = os.time()
    while not conditionFunc() do
        if os.difftime(os.time(), startTime) >= timeout then
            print("Stopped waiting for " .. message .. " after " .. timeout .. " seconds.")
            break
        end
        if not API.Read_LoopyLoop() then
            print("Script exited - breaking sleep.")
            break
        end
        if callback then
            debugPrint("Executing callback during sleepUntil for " .. message)
            callback()
        end
        API.RandomSleep2(100, 100, 100)
    end
    if conditionFunc() then
        print("Sleep condition met for " .. message)
    end
end

local function isPointInPolygon(point, polygon)
    local count = 0
    local n = #polygon
    for i = 1, n do
        local j = i % n + 1
        local vertex1 = polygon[i]
        local vertex2 = polygon[j]
        if ((vertex1.y > point.y) ~= (vertex2.y > point.y)) and
           (point.x < (vertex2.x - vertex1.x) * (point.y - vertex1.y) / (vertex2.y - vertex1.y) + vertex1.x) then
            count = count + 1
        end
    end
    local inside = count % 2 == 1
    if inside then
       -- debugPrint("isPointInPolygon: point (" .. point.x .. ", " .. point.y .. ") is inside the polygon")
    end
    return inside
end


local function findPlayerIsland(playerX, playerY, islands)
    for mapNumber, mapIslands in ipairs(islands) do
        for islandIndex, island in ipairs(mapIslands) do
            if isPointInPolygon({x = playerX, y = playerY}, island) then
                debugPrint("Player found on island " .. islandIndex .. " of map " .. mapNumber)
                return mapNumber, islandIndex
            end
        end
    end
    debugPrint("Player is not on any known island")
    return nil
end

-- Retrieve player coordinates
local coord = API.PlayerCoord()
local playerX = coord.x
local playerY = coord.y

local mapNumber, islandIndex = findPlayerIsland(playerX, playerY, islands)
if mapNumber and islandIndex then
    print("Player is on island " .. islandIndex .. " of map " .. mapNumber)
else
    print("Player is not on any known island")
end

local ITEM_IDS = {
    essence = 24227
}

local ENTITY_TYPES = {
    object = 0,
    npc = 1
}

local floatingEssenceID = 15402 
local minimumEssenceAmount = 20
local objectEssenceAmount = 100

local NPC_IDS = {
    air_essling   = { id = {15273, 15403}, level_required = 1 },
    mind_essling  = { id = {15274, 15404}, level_required = 1 },
    water_essling = { id = 15405, level_required = 5 },
    earth_essling = { id = {15276, 15406}, level_required = 9 },
    fire_essling  = { id = {15277, 15407}, level_required = 14 },
    body_esshound = { id = 15408, level_required = 20 },
    cosmic_esshound = { id = 15409, level_required = 27 },
    chaos_esshound  = { id = 15410, level_required = 35 },
    astral_esshound = { id = 15411, level_required = 40 },
    nature_esshound = { id = 15412, level_required = 44 },
    law_esshound    = { id = 15413, level_required = 54 },
    death_esswraith = { id = 15414, level_required = 65 },
    blood_esswraith = { id = 15415, level_required = 77 },
    soul_esswraith  = { id = 15416, level_required = 90 },
}

local OBJECT_IDS = {
    cyclone       = { id = 70455, level_required = 1 },
    mind_storm    = { id = 70456, level_required = 1 },
    water_pool    = { id = 70457, level_required = 5 },
    rock_fragment = { id = 70458, level_required = 9 },
    fireball      = { id = 70459, level_required = 14 },
    vine          = { id = 70460, level_required = 17 },
    fleshy_growth = { id = 70461, level_required = 20 },
    fire_storm    = { id = 70462, level_required = 27 },
    chaotic_cloud = { id = 70463, level_required = 35 },
    nebula        = { id = 70464, level_required = 40 },
    shifter       = { id = 70465, level_required = 44 },
    jumper        = { id = 70466, level_required = 54 },
    skulls        = { id = 70467, level_required = 65 },
    blood_pool    = { id = 70468, level_required = 77 },
    blood_skulls  = { id = 70469, level_required = 83 },
    living_pool   = { id = 70470, level_required = 90 },
    undead_soul   = { id = 70471, level_required = 95 },
}

local function getRunecraftingLevel() 
    local currentExp = API.GetSkillXP("RUNECRAFTING")
    local level = API.XPLevelTable(currentExp)
    return level
end

-- Modify isEntityInIsland to only print debug if the entity is inside the island
local function isEntityInIsland(entity, island)
    local adjustedX = entity.TileX / 512
    local adjustedY = entity.TileY / 512
    local inside = isPointInPolygon({x = adjustedX, y = adjustedY}, island)
    if inside then
      --  debugPrint("Entity at (" .. entity.TileX .. ", " .. entity.TileY .. ") adjusted to (" .. adjustedX .. ", " .. adjustedY .. ") is inside the island")
    end
    return inside
end

-- Build a table of all valid entities (from the given table) found within the island.
local function findAllEntitiesInIsland(entities, playerLevel, island, entityType)
    local validEntities = {}
    for key, entity in pairs(entities) do
        local entityIds = type(entity.id) == "table" and entity.id or {entity.id}
        local levelRequired = entity.level_required
        if levelRequired and levelRequired <= playerLevel then
            for _, entityId in ipairs(entityIds) do
                local result = API.GetAllObjArrayInteract({entityId}, 50, {entityType})
                for _, foundEntity in ipairs(result) do
                    if isEntityInIsland(foundEntity, island) then
                        table.insert(validEntities, {name = key, data = entity, entityType = entityType})
                        break
                    end
                end
            end
        end
    end
    return validEntities
end

-- Print the table of found entities sorted by required level (descending)
local function printSortedEntities(validEntities)
    table.sort(validEntities, function(a, b)
        return a.data.level_required > b.data.level_required
    end)
    print("Entities found on island (sorted by required level descending):")
    for i, entry in ipairs(validEntities) do
        local typeStr = (entry.entityType == ENTITY_TYPES.object) and "object" or "npc"
        print(i .. ". " .. entry.name .. " (" .. typeStr .. ") - Level required: " .. entry.data.level_required)
    end
end

local function siphonEntity(highestEntity, entityType)
    local idStr = ""
    if type(highestEntity.id) == "table" then
        for i, id in ipairs(highestEntity.id) do
            idStr = idStr .. tostring(id)
            if i < #highestEntity.id then
                idStr = idStr .. ", "
            end
        end
    else
        idStr = tostring(highestEntity.id)
    end

    print("Highest level " .. ((entityType == ENTITY_TYPES.object) and "object" or "npc") ..
          " ID: " .. idStr .. ", Level required: " .. highestEntity.level_required)
    debugPrint("Attempting to siphon entity with ID(s): " .. idStr)

    local actionFunction = (entityType == ENTITY_TYPES.object) and API.DoAction_Object1 or API.DoAction_NPC
    local actionType = (entityType == ENTITY_TYPES.object) and API.OFF_ACT_GeneralObject_route0 or API.OFF_ACT_InteractNPC_route
    if actionFunction(0x29, actionType, (type(highestEntity.id) == "table" and highestEntity.id or {highestEntity.id}), 50) then
        debugPrint("Action performed successfully, sleeping after action.")
        API.RandomSleep2(2000, 1000, 2000)
    else
        debugPrint("Action failed for entity with ID(s): " .. idStr)
    end
end

local function collectEssence()
    debugPrint("Attempting to collect essence using floatingEssenceID: " .. tostring(floatingEssenceID))
    if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, {floatingEssenceID}, 50) then
        sleepUntil(function() return API.InvStackSize(ITEM_IDS.essence) > minimumEssenceAmount end, 10, "Gathered essence")
    else
        debugPrint("Failed to initiate essence collection action.")
    end
end

local function trainRC()
    local playerLevel = getRunecraftingLevel()
    local currentIsland = islands[mapNumber][islandIndex]
    local essence = API.InvStackSize(ITEM_IDS.essence)
    debugPrint("Running trainRC: Player level: " .. playerLevel .. ", Essence: " .. essence)

    -- Gather valid entities from both objects and NPCs
    local validObjects = findAllEntitiesInIsland(OBJECT_IDS, playerLevel, currentIsland, ENTITY_TYPES.object)
    local validNPCs = findAllEntitiesInIsland(NPC_IDS, playerLevel, currentIsland, ENTITY_TYPES.npc)
    local validEntities = {}
    for _, entry in ipairs(validObjects) do table.insert(validEntities, entry) end
    for _, entry in ipairs(validNPCs) do table.insert(validEntities, entry) end

    if #validEntities > 0 then
        -- Sort and print the table of valid entities
        printSortedEntities(validEntities)
        -- The highest-level entity is now the first entry in the sorted table.
        local highest = validEntities[1]
        siphonEntity(highest.data, highest.entityType)
    else
        debugPrint("No suitable entity found, collecting essence instead.")
        collectEssence()
    end
end

-- Common checks: random events, XP gain, idle check, etc.
local afk = os.time()  -- Initialize last active time
local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((5 * 60) * 0.6, (5 * 60) * 0.9)
    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
        debugPrint("Idle action triggered.")
    end
end

local function gameStateChecks()
    local gameState = API.GetGameState2()
    if (gameState ~= 3) then
        print('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
end

API.SetDrawTrackedSkills(true)
API.ScriptRuntimeString()
API.GetTrackedSkills()

API.Write_ScripCuRunning1("Current Task: Runespan")

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    gameStateChecks()
    idleCheck()

    if not API.ReadPlayerMovin2() and not API.CheckAnim(20) then
        trainRC()
    end

    API.RandomSleep2(300, 300, 300)
end

API.SetDrawTrackedSkills(false)

print("debug : ...... Script finished execution.")

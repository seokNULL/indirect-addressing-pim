#include "convert_numeric.h"


float generate_random()
{
  //return (rand() / (float)RAND_MAX * 0.25f)+(-0.125);

  //0~ 0.1  --> -0.05~0.05
  return (rand() / (float)RAND_MAX * 0.01f) + (-0.0025);
}

float generate_random_255()
{
  //0~2
  return (rand() / (float)RAND_MAX * 2.0f);
}

// Convert the 32-bit binary encoding into hexadecimal
int Binary2Hex( std::string Binary )
{
  std::bitset<32> set(Binary);      
  int hex = set.to_ulong();
   
  return hex;
}
 
// Convert the 32-bit binary into the decimal
float GetFloat( std::string Binary )
{
  int HexNumber = Binary2Hex( Binary );

  bool negative  = !!(HexNumber & 0x80000000);
  int  exponent  =   (HexNumber & 0x7f800000) >> 23;    
  int sign = negative ? -1 : 1;

  // Subtract 127 from the exponent
  exponent -= 127;

  // Convert the mantissa into decimal using the
  // last 23 bits
  int power = -1;
  float total = 0.0;
  for ( int i = 0; i < 23; i++ )
  {
      int c = Binary[ i + 9 ] - '0';
      total += (float) c * (float) pow( 2.0, power );
      power--;
  }
  total += 1.0;

  float value = sign * (float) pow( 2.0, exponent ) * total;

  return value;
}
 
// Get 32-bit IEEE 754 format of the decimal value
std::string GetBinary( float value )
{
  union
  {
    float input;   // assumes sizeof(float) == sizeof(int)
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(float) * CHAR_BIT>   bits(data.output);
  std::string mystring = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  return mystring;
}

// Get 32-bit IEEE 754 format of the decimal value
std::string convert_16bit( float value )
{
  union
  {
    float input;   // assumes sizeof(float) == sizeof(int)
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(float) * CHAR_BIT>   bits(data.output);
  std::string str = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  str = str.substr(0,16);
  return str;
}

short float_to_short( float value )
{
  union
  {
    float input;   // assumes sizeof(float) == sizeof(int)
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(float) * CHAR_BIT>   bits(data.output);
  std::string str = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  str = str.substr(0,16);
  return std::stoi(str, nullptr, 2);
}

float short_to_float (short value)
{
  union
  {
    short input;
    int   output;
  }data;

  data.input = value;
  std::bitset<sizeof(short) * CHAR_BIT>   bits(data.output);
  std::string mystring = bits.to_string<char, 
                                        std::char_traits<char>,
                                        std::allocator<char> >();
  //std::cout<<mystring<<std::endl;
  mystring.append("0000000000000000");
  //std::cout<<mystring<<std::endl;

  return GetFloat(mystring);
  //std::cout<<test<<std::endl;  
}


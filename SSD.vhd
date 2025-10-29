
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SSD is
    port(
	current_floor: in std_logic_vector(3 downto 0);
	SSD_Out: out std_logic_vector(6 downto 0)
    );
end SSD;

architecture SSD_Architecture of SSD is
begin
    process(current_floor)
    begin
       case current_floor is
        when "0000" => SSD_Out <= "1000000";      
        when "0001" => SSD_Out <= "1111001"; 
        when "0010" => SSD_Out <= "0100100"; 
        when "0011" => SSD_Out <= "0110000"; 
        when "0100" => SSD_Out <= "0011001"; 
        when "0101" => SSD_Out <= "0010010"; 
        when "0110" => SSD_Out <= "0000010"; 
        when "0111" => SSD_Out <= "1111000"; 
        when "1000" => SSD_Out <= "0000000"; 
        when "1001" => SSD_Out <= "0011000"; 
        when others => SSD_Out <= "0111111"; 
       end case;
    end process;
end SSD_Architecture;

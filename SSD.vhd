library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SSD is
    port(
	floor: in std_logic_vector(3 downto 0);
	output: out std_logic_vector(6 downto 0)
    );
   
end SSD;

architecture SSD_Architecture of SSD is
begin
    process(floor)
    begin
        case floor is
            when "0000" =>
                output <= "1111110";
            when "0001" =>
                output <= "0110000";
            when "0010" =>
                output <= "1101101";
            when "0011" =>
                output <= "1111001";
            when "0100" =>
                output <= "0110011";
            when "0101" =>
                output <= "1011011";
            when "0110" =>
                output <= "1011111";
            when "0111" =>
                output <= "1110000";
            when "1000" =>
                output <= "1111111";
            when "1001" =>
                output <= "1111011";
            when others =>
                output <= "0000001";
        end case;
    end process;
end SSD_Architecture;

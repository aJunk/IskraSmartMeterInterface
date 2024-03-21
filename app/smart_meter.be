import webserver
import string
import mqtt

import crypto


var CRC_INIT=0xffff
var POLYNOMIAL=0x1021

def byte_mirror(c)
    var cc = c
    cc=(cc&0xF0)>>4|(cc&0x0F)<<4
    cc=(cc&0xCC)>>2|(cc&0x33)<<2
    cc=(cc&0xAA)>>1|(cc&0x55)<<1
    return cc
end

def calc_crc16(data)
    var ccrc = CRC_INIT
    for i : 0..(data.size()-1)
        var c = byte_mirror(data[i])<<8
        for j : 0..7
            if (ccrc^c) & 0x8000
                ccrc=(ccrc<<1)^POLYNOMIAL
            else
                ccrc=ccrc<<1
            end
            ccrc=ccrc%65536
            c=(c<<1)%65536
        end
    end
    ccrc=0xFFFF-ccrc
    ccrc = 256 * byte_mirror(int(ccrc/256)) + byte_mirror(ccrc%256)
    return ccrc
end



class SmartMeterInterface: Driver

    var ser 
    var buf
    var tick

    var key
    var aes

    var packet
    var plaintext

    var sync

    var a, b, c, d, e, f, g, h

    var dd, mm, yyyy 
    var hh, mi, ss

    var mqtt_publish_topic

    def every_100ms()
        if !self.ser 
            print('Serial crashed!')
            return nil
        end 

        if self.ser.available()
            self.buf += self.ser.read()
        elif self.tick > 3 && self.buf.size() > 0
            if self.buf.size() == 105
                #print("Ciphertext: ", self.buf.tohex())
                var len = self.buf.size()
                var data = self.buf[1..-4]
                var goal = self.buf[-3..-2]
                var checksum = calc_crc16(data)
                if checksum == goal.get(0,-2)
                    self.decrypt()
                    self.mqtt()
                else
                    print('CRC mismatch!')
                end
            end
            self.tick = 0
            self.buf = bytes()
        elif self.buf.size() > 0
            self.tick += 1
        end
    end

    def decrypt()
        var ciphertext = self.buf[28..-4]
        var iv = self.buf[14..21] + self.buf[24..27]
        self.plaintext = self.aes.decrypt(ciphertext, iv, 2)
        
        self.a = self.plaintext[35..38].get(0,-4)/1000.000  
        self.b = self.plaintext[40..43].get(0,-4)/1000.000  
        self.c = self.plaintext[45..48].get(0,-4)/1000.000  
        self.d = self.plaintext[50..53].get(0,-4)/1000.000  
        self.e = self.plaintext[55..58].get(0,-4)           
        self.f = self.plaintext[60..63].get(0,-4) 
        self.g = self.plaintext[65..68].get(0,-4) 
        self.h = self.plaintext[70..73].get(0,-4) 
        
        self.yyyy = self.plaintext[22..23].get(0,-2)
        self.mm = self.plaintext[24]
        self.dd = self.plaintext[25]

        self.hh = self.plaintext[27]
        self.mi = self.plaintext[28]
        self.ss = self.plaintext[29]
    end

  

    def init(key, mqtt_publish_topic)
        self.ser = serial(6, -1, 9600, serial.SERIAL_8N1)
        self.buf = bytes()
        self.tick = 0

        self.key = bytes(key)
        self.aes = crypto.AES_CTR(self.key)
        
        self.mqtt_publish_topic = mqtt_publish_topic

        self.sync = false
        self.ser.flush()

    end

    def deinit()
    end

    def mqtt()
        if !self.ser return nil end  #- exit if not initialized -#

        var time_str_raw = string.format("%04d.%02d.%02d %02d:%02d:%02d", self.yyyy, self.mm, self.dd, self.hh, self.mi, self.ss)
        var time_str = tasmota.strptime(time_str_raw, "%Y.%m.%d %H:%M:%S")
        
        time_str['epoch'] -= 3600

        var meter_string = string.format("{\"timestamp\":%s,"..
            "\"energyRealPositive\":%.3f,"..
            "\"energyRealNegative\":%.3f,"..
            "\"energyReactivePositive\":%.3f,"..
            "\"energyReactiveNegative\":%.3f,"..
            "\"powerRealPositive\":%d,"..
            "\"powerRealNegative\":%d,"..
            "\"powerReactivePositive\":%d,"..
            "\"powerReactiveNegative\":%.d"..
            "}",
            time_str,
            self.a, self.b, self.c, self.d, self.e, self.f, self.g, self.h)

        var msg = string.format("{\"localtime\":%s, \"data\":%s}", tasmota.rtc(), meter_string)
        
        # Replace single quotes with double quotes. Clunky but works...
        var split = string.split(msg, "\'")
        msg = split[0]
        if split.size() > 1
          for i: 1 .. (split.size()-1)
            msg += "\"" + split[i]
          end
        end


        mqtt.publish(self.mqtt_publish_topic, msg)


    end
#var msg = string.format("Output: %10.3fkWh, %10.3fkWh, %10.3fkvarh, %10.3fkvarh, %5dW, %5dW at %02d.%02d.%04d-%02d:%02d:%02d",

    def web_sensor()
        var msg = string.format(
             "{s}Energy + [real]{m}%.3f kWh{e}"..
             "{s}Energy - [real]{m}%.3f kWh{e}"..
             "{s}Energy +[reactive]{m}%.3f kVARh{e}"..
             "{s}Energy +[reactive]{m}%.3f kVARh{e}"..
             "{s}Power + [real]{m}%5d W{e}"..
             "{s}Power - [real]{m}%5d W{e}"..
             "{s}Power + [reactive]{m}%5d VA{e}"..
             "{s}Power - [reactive]{m}%5d VA{e}",
             self.a, self.b, self.c, self.d, self.e, self.f, self.g, self.h)
            tasmota.web_send_decimal(msg)
    end
end

import json

f = open('smart_meter_config.json')
data = f.read()
d = json.load(data)
f.close()

meter = SmartMeterInterface(d['key'], d['topic'])

tasmota.add_driver(meter)
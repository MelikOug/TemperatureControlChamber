import serial
import numpy as np
import statistics
import matplotlib.pyplot as plt
import time
import sys


def get_data():
    buffer_string = ''
    ser.flushInput()  # Clear buffer
    while True:
        if ser.in_waiting >= 256:
            # Should include at least 2 terminator strings
            buffer_string = ser.read(256)
            # Extract one whole line of 64 pixel data
            line = buffer_string.split(b'\n')[1].hex()
            buffer_string = ''

            'Convert Data'
            pixel_data = []
            data = []
            temperature = []
            temperature_array = []

            'Converting Hex to Data'
            for i in range(0, len(line), 4):
                pixel_data = (line[i:i+4])  # 4 bytes of hex = 1 pixel
                # Add to data list and swap nibbles
                data.append(''.join(pixel_data[2:4]+pixel_data[0:2]))

            # Add current 24hr time to variable
            clock = time.strftime("%H:%M:%S")
            # Convert hex data to temperature
            temperature = np.array([int(hex_string, 16)
                                   for hex_string in data])/4
            average = (sum(temperature)/len(temperature))
            std = statistics.stdev(temperature)

            'Form into matrix (8x8)'
            for i in range(0, 64, 8):
                temperature_array.append([float(x)
                                         for x in temperature[i:(i+8)]])

            'Rotate matrix 180 degrees to convert to sensor POV'
            reversed_rows = [row[::-1] for row in temperature_array]
            temperature_array = reversed_rows[::-1]
            return temperature_array, average, std, clock
        else:
            continue


def update():
    'Plot'

    plt.ion()
    fig = plt.figure(dpi=100)
    ax = fig.gca()
    ax.set_xticks(np.arange(len(columns)))
    ax.set_yticks(np.arange(len(rows)))
    ax.set_xticklabels(columns)
    ax.set_yticklabels(rows)

    ax.set_title("Surface Temperature Reading (Sensor POV)")
    fig.tight_layout()

    new_data = get_data()
    im = plt.imshow(new_data[0], cmap='gnuplot2')#, interpolation='spline36')
    #plt.clim(15, 40)
    fig.colorbar(im)

    Flattened_Array = np.array(new_data[0]).flatten()
    meanT = str(round(new_data[1], 1))
    std = str(round(new_data[2], 3))
    minT = str(round(min(Flattened_Array), 1))
    maxT = str(round(max(Flattened_Array), 1))
    timestamp = new_data[3]

    plt.text(0, 7, "$T_{mean} =$ %s" % meanT + '$\degree$' + 'C', bbox={
             'facecolor': 'oldlace', 'alpha': 0.5, 'pad': 8})

    plt.text(4.6, 7, "$\sigma = $  %s" % std, bbox={
             'facecolor': 'oldlace', 'alpha': 0.5, 'pad': 8})

    plt.text(0, 0.2, "$T_{min} =$ %s" % minT + '$\degree$' + 'C', bbox={
             'facecolor': 'oldlace', 'alpha': 0.5, 'pad': 8})

    plt.text(4.6, 0.2, "$T_{max} =$ %s" % maxT + '$\degree$' + 'C', bbox={
             'facecolor': 'oldlace', 'alpha': 0.5, 'pad': 8})
    plt.show()

    data = np.array([timestamp, meanT, minT, maxT, std])
    # print(data)
    np.savetxt(f, data, delimiter=' ', newline=' ', fmt='%s')
    f.write('\n')


ser = serial.Serial(
    port='COM4',
    baudrate=9600,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1
)

rows = ["1", "2", "3", "4",
        "5", "6", "7", "8"][::-1]

columns = ["1", "2", "3", "4",
           "5", "6", "7", "8"]

print("Initializing AMG8833 8x8 Infrared Camera ...")
f = open("TCC_Data.txt", "a")
f.truncate(0)  # Clear file data
while True:
    try:
        update()
    except KeyboardInterrupt:
        f.close()
        sys.exit

import matplotlib.pyplot as plt
import numpy as np
temp = str(23)
clock, meanT, minT, maxT, std = np.loadtxt(
    'C:\\Users\\44738\\OneDrive - Imperial College London\\Documents\\TCC Osc Data\\TCC_Data_Osc'+temp+'.txt', unpack=True, dtype=str)
hours, minutes, seconds = np.array(
    [time.split(':') for time in clock], dtype=int).T
total_seconds = (hours * 3600) + (minutes*60) + seconds
total_seconds_shifted = total_seconds - total_seconds[0]

meanT = meanT.astype(float)
minT = minT.astype(float)
maxT = maxT.astype(float)
std = std.astype(float)


clock2, PTemp = np.loadtxt(
    'C:\\Users\\44738\\OneDrive - Imperial College London\\Documents\\Peltier Osc Data\\Peltier_Osc'+temp+'.txt', unpack=True, usecols=(1, 3), dtype=str, skiprows=1)
clock2 = np.array([date[-8:] for date in clock2])
PTemp = PTemp.astype(float)
hours, minutes, seconds = np.array(
    [time.split(':') for time in clock2], dtype=int).T
total_seconds2 = (hours * 3600) + (minutes*60) + seconds
total_seconds2_shifted = total_seconds2 - total_seconds[0]


fig = plt.figure(dpi=500)
ax = fig.add_subplot()
ax.grid()
ax.set_xlabel('Time ($Seconds$)')
ax.set_ylabel('Temperature '+'($\degree$' + 'C)')
ax.errorbar(total_seconds_shifted, meanT, ls='-',
            marker='.', label='Mean Temperature', yerr=std)
ax.plot(total_seconds_shifted, minT, ls='-',
        marker='.', label='Minimum Temperature')
ax.plot(total_seconds_shifted, maxT, ls='-',
        marker='.', label='Maximum Temperature')
ax.plot(total_seconds2_shifted, PTemp, label='Peltier Temperature')
#ax.plot(seconds, std, ls = '-', marker = '.',label = "$\sigma$")
ax.legend()

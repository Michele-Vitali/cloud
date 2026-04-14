import matplotlib.pyplot as plt

# Legge i valori dal file (in secondi)
with open("durations.txt", "r", encoding="utf-8") as f:
    durations = [int(line.strip()) for line in f if line.strip()]

# Filtra tra 0 e 5000 secondi
durations_filtered = [d for d in durations if 0 <= d <= 5000]

# Converte in minuti
durations_minutes = [d / 60 for d in durations_filtered]

# Istogramma
plt.figure(figsize=(10, 6))
plt.hist(durations_minutes, bins=50, edgecolor='black')

plt.title("Distribuzione delle durate dei video")
plt.xlabel("Durata (minuti)")
plt.ylabel("Numero di video")

# Asse X da 0 a 5000 secondi convertiti in minuti
plt.xlim(0, 2000 / 60)

plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()
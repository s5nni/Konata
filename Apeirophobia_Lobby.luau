local Attempts = 0
repeat Attempts = Attempts + 1; wait(1); print(Attempts) until getgenv().__Mitulib.Key == Configuration.Initialize.Place.Key
getgenv().__Mitulib.Key = nil

warn("Loaded.")

local Attempts = 0
repeat Attempts = Attempts + 1; wait(1); print(Attempts) until getgenv().__Mitulib.Authorized == true
getgenv().__Mitulib.Authorized = nil

warn("Loaded.")

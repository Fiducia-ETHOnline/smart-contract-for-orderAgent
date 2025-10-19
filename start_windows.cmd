@echo off
for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
    if not "%%A"=="" (
        if not "%%A"=="#" (
            set %%A=%%B
        )
    )
)
echo OK .env variables loaded into current session.

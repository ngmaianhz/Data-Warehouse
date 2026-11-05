@echo off
REM Chay dashboard GD5.1 (Streamlit) tren Windows. Nhap dup de chay; neu dang chay ban cu thi tu tat roi mo lai.
cd /d "%~dp0"
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8501" ^| findstr "LISTENING"') do taskkill /PID %%p /F >nul 2>&1
if exist venv\Scripts\activate.bat call venv\Scripts\activate.bat
python -m pip install -q -U "streamlit>=1.50" plotly
python -m streamlit run app\01_app_dashboard.py --server.headless true --server.port 8501
pause

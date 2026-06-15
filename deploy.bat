@echo off
chcp 65001 >nul
echo ===================================================
echo 🧋 Bubble Tea Tycoon - Git Sync ＆ PWA Deployment v1.2.8 🧋
echo ===================================================
echo.
echo [1/3] 正在將修改的安全修復檔案加入 Git 暫存區...
git add index.html sw.js leaderboard.html google-apps-script-guide.md security_report.md
echo.
echo [2/3] 正在提交版本更新 (v1.2.8)...
git commit -m "chore: release v1.2.8 - fix global leaderboard formula injection and cheating protection"
echo.
echo [3/3] 正在推送到 GitHub 遠端庫 (main 分支)...
git push origin main
echo.
echo ===================================================
echo 🎉 Git 更新完成！ GitHub Pages 將在 1-2 分鐘內自動完成部署。
echo ===================================================
echo.
pause

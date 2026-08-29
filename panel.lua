local guncellemeURL = "https://raw.githubusercontent.com/vBothNick/Updater/main/update.txt"
local SURUM = "20.6"

script_name("MIMGUI Modern Arayuz Paneli")
script_author("Jakuzi")
script_version(SURUM)

require "lib.moonloader"
local vkeys = require 'vkeys'
local imgui = require 'mimgui'
local ffi = require 'ffi'
local inicfg = require 'inicfg'
local bit = require 'bit'

local sampev_yuklu, sampev = pcall(require, 'samp.events')

local encoding_yuklu, encoding = pcall(require, 'encoding')
local u8, u8_decode
if encoding_yuklu then
    encoding.default = 'CP1254'
    u8 = encoding.UTF8
    u8_decode = function(s) return encoding.UTF8:decode(s) end
else
    u8 = function(s) return s end
    u8_decode = function(s) return s end
end

-- ==========================================
-- OTOMATİK GÜNCELLEME MODÜLÜ (GÜVENLİ SİSTEM)
-- ==========================================
local guncellemeURL = "https://raw.githubusercontent.com/vBothNick/Updater/main/update.txt"
local scriptYolu = thisScript().path

function otomatikGuncellemeKontrolu()
    lua_thread.create(function()
        wait(2000) -- Oyun açıldıktan sonra 2 saniye bekler, sistemin rahatlamasını sağlar.
        downloadUrlToFile(guncellemeURL, getWorkingDirectory() .. "\\update_check.txt", function(id, status, p1, p2)
            if status == 58 then 
                local f = io.open(getWorkingDirectory() .. "\\update_check.txt", "r")
                if f then
                    local sunucuVerisi = f:read("*a")
                    f:close()
                    os.remove(getWorkingDirectory() .. "\\update_check.txt") 
                    
                    local sunucuSurum, indirmeLinki = sunucuVerisi:match("([%d%.]+)|(.+)")
                    
                    if sunucuSurum and indirmeLinki then
                        local mevcutSurumNumarasi = tonumber(SURUM:match("[%d%.]+")) or 0
                        local sunucuSurumNumarasi = tonumber(sunucuSurum) or 0
                        
                        if sunucuSurumNumarasi > mevcutSurumNumarasi then
                            sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Panel icin yeni bir guncelleme bulundu (v" .. sunucuSurum .. "). Indiriliyor...", -1)
                            
                            local geciciDosya = getWorkingDirectory() .. "\\panel_yeni.lua"
                            downloadUrlToFile(indirmeLinki, geciciDosya, function(id2, status2, p12, p22)
                                if status2 == 58 then
                                    local yeniKod = io.open(geciciDosya, "r")
                                    local asilKod = io.open(scriptYolu, "w")
                                    
                                    if yeniKod and asilKod then
                                        asilKod:write(yeniKod:read("*a"))
                                        yeniKod:close()
                                        asilKod:close()
                                        os.remove(geciciDosya)
                                        
                                        sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Guncelleme basariyla kuruldu! Panel yeniden baslatiliyor...", -1)
                                        thisScript():reload()
                                    else
                                        if yeniKod then yeniKod:close() end
                                        if asilKod then asilKod:close() end
                                        sampAddChatMessage("{FF0000}[Hata] {FFFFFF}Guncelleme yapilamadi. Dosya bir editor tarafindan acik tutuluyor olabilir.", -1)
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end)
    end)
end
-- ==========================================

fontFiles = {
    {"Arial (Varsayilan)", "arial.ttf"}, {"Tahoma", "tahoma.ttf"}, {"Verdana", "verdana.ttf"},
    {"Trebuchet MS", "trebuc.ttf"}, {"Comic Sans MS", "comic.ttf"}, {"Courier New", "cour.ttf"},
    {"Impact", "impact.ttf"}, {"Times New Roman", "times.ttf"}
}

mevcutFontIsimleri = {}
mevcutFontPointers = {}
fontComboCount = 0
fontComboItems = nil
fontNamesPointers = {} 

glyph_ranges = imgui.new.ImWchar[7](0x0020, 0x00FF, 0x0100, 0x017F, 0x0400, 0x04FF, 0)
bgTexture = nil

-- ANİMASYON DURUMLARI (BOOT & FADE)
local isMenuOpen = false
local animState = 0 -- 0: Kapali, 1: Aciliyor, 2: Acik, 3: Kapaniyor
local animProgress = 0.0
local bootState = 0 -- 0: Hic acilmadi, 1: Yukleniyor, 2: Jakuzi, 3: Tamamlandi
local bootStartTime = 0

imgui.OnInitialize(function()
    local config = imgui.ImFontConfig()
    for i, data in ipairs(fontFiles) do
        local path = os.getenv("WINDIR") .. "\\Fonts\\" .. data[2]
        local f = io.open(path, "r")
        if f then
            f:close()
            local ptr = imgui.GetIO().Fonts:AddFontFromFileTTF(path, 16.0, config, glyph_ranges)
            table.insert(mevcutFontIsimleri, data[1])
            table.insert(mevcutFontPointers, ptr)
        end
    end
    
    fontComboCount = #mevcutFontIsimleri
    if fontComboCount > 0 then
        fontComboItems = ffi.new('const char*[?]', fontComboCount)
        for i, isim in ipairs(mevcutFontIsimleri) do
            fontNamesPointers[i] = imgui.new.char[256](isim)
            fontComboItems[i - 1] = fontNamesPointers[i]
        end
    end
    
    local bgPath = getWorkingDirectory() .. "\\arkaplan.jpg"
    local bgFile = io.open(bgPath, "rb")
    if bgFile then
        bgFile:close()
        bgTexture = imgui.CreateTextureFromFile(bgPath)
    end
end)

iniFile = "SAMP_OzelPanel.ini"
animDosya = getWorkingDirectory() .. "\\ModernHUB_Animasyonlar.txt"

mainIni = inicfg.load({
    isimler = {}, komutlar = {}, rp_isimler = {}, rp_komutlar = {}, radar = {}, oto_mesajlar = {},
    ayarlar = { 
        kisayol_v2 = 113, mouse_kisayol_v2 = 4, secili_font = 0, chatlog_count = 1,
        tema_r = 0.20, tema_g = 0.55, tema_b = 0.95, yuvarlaklik = 8.0,
        mouse_tip = 1, ses_ve_efekt = true,
        rgb_border = false, anim_arkaplan = 1, kamera_sabitle = false
    },
    afk = { aktif = false, tetikleyici = "Kullanici", mesaj = "Su an klavye basinda degilim, daha sonra donus yapacagim." },
    rol_filtre = { aksan_aktif = false, aksan_metin = "[Ispanyolca] ", telsiz_aktif = false },
    oto_arac = { kemer = false, motor = false }
}, iniFile)

function getKeyName(id)
    if id == 0 or id == nil then return "Atanmadi" end
    for k, v in pairs(vkeys) do
        if v == id and type(k) == "string" and k:sub(1,3) == "VK_" then return k:sub(4) end
    end
    return tostring(id)
end

function formatNumber(n)
    local left,num,right = string.match(tostring(n),'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

patched_time = nil
g_SabitZaman = nil

function patch_samp_time_set(enable)
    if enable and patched_time == nil then
        patched_time = readMemory(sampGetBase() + 0x9C0A0, 4, true)
        writeMemory(sampGetBase() + 0x9C0A0, 4, 0x000008C2, true)
    elseif enable == false and patched_time ~= nil then
        writeMemory(sampGetBase() + 0x9C0A0, 4, patched_time, true)
        patched_time = nil
    end
end

function getRiskTekZar(score)
    if score >= 21 then return 100.0 end
    local safe_rolls = 21 - score
    if safe_rolls >= 6 then return 0.0 end
    local bust_rolls = 6 - safe_rolls
    return (bust_rolls / 6.0) * 100.0
end

function getRiskCiftZar(score)
    if score >= 21 then return 100.0 end
    local safe_rolls = 21 - score
    if safe_rolls >= 12 then return 0.0 end
    local combinations = { [2]=1, [3]=2, [4]=3, [5]=4, [6]=5, [7]=6, [8]=5, [9]=4, [10]=3, [11]=2, [12]=1 }
    local bust_count = 0
    for i = 2, 12 do
        if (score + i) > 21 then bust_count = bust_count + combinations[i] end
    end
    return (bust_count / 36.0) * 100.0
end

mouseTipleriListesi = {"Varsayilan (SAMP)", "Neon Ok", "Minimal Nokta", "Crosshair"}
mouseTipItems = ffi.new('const char*[?]', #mouseTipleriListesi)
mouseTipPointers = {}
for i, v in ipairs(mouseTipleriListesi) do
    mouseTipPointers[i] = imgui.new.char[256](v)
    mouseTipItems[i - 1] = mouseTipPointers[i]
end

arkaplanIsimleri = {"Kapali (Varsayilan)", "Yildiz Yagmuru", "Matrix Etkisi", "Kar Yagisi", "Yukselen Baloncuklar", "Meteor Yagmuru"}
arkaplanItems = ffi.new('const char*[?]', #arkaplanIsimleri)
arkaplanPointers = {}
for i, v in ipairs(arkaplanIsimleri) do
    arkaplanPointers[i] = imgui.new.char[256](v)
    arkaplanItems[i - 1] = arkaplanPointers[i]
end

havaDurumuIsimleri = {"Gunesli Acik", "Bulutlu", "Yagmurlu", "Sisli", "Kizil Gokyuzu (Aksam)", "Gece Karanligi", "Kum Firtinasi"}
havaDurumuIDs = {1, 2, 8, 9, 23, 32, 19}
havaDurumuItems = ffi.new('const char*[?]', #havaDurumuIsimleri)
havaDurumuPointers = {}
for i, v in ipairs(havaDurumuIsimleri) do
    havaDurumuPointers[i] = imgui.new.char[256](v)
    havaDurumuItems[i - 1] = havaDurumuPointers[i]
end

function BilgiKutusu(metin)
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.5, 0.8, 0.9, 1.0), "(?)")
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(imgui.GetFontSize() * 35.0)
        imgui.TextUnformatted(metin)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

charStats = {
    isim = "Bilinmiyor", seviye = "0", exp = "0/0", cinsiyet = "Bilinmiyor", dogum = "Bilinmiyor",
    para = "$0", banka = "$0", birlik = "Yok", rutbe = "Yok", telefon = "Bilinmiyor", meslek = "Issiz",
    vip = "Yok", saat = "0", medeni = "Bekar", es = "Yok", payday = "0 dk", maas = "0 dk",
    can = "100.0", zirh = "0.0", market = "0 vP", tc_no = "Bilinmiyor", uyruk = "Bilinmiyor",
    ehliyet = "Bilinmiyor", ucus = "Bilinmiyor", silah = "Bilinmiyor"
}

bjPlayers = {}
bjData = {}

sesStartT = os.time()
sesFootDist = 0.0
sesCarDist = 0.0
sesMsgCount = 0
sesMoneyEarned = 0
sesMoneyLost = 0
sesCarsUsed = 0
sesPlayersSeen = {}
sesAfkTime = 0
sesMaxSpeed = 0.0
sesShotsFired = 0
sesLastPx, sesLastPy, sesLastPz = 0, 0, 0
sesLastVeh = 0
sesLastMoney = 0
sesLastActive = os.clock()

favoritePlayers = {}
favoriteAlerted = {}
yeniKankaIsim = imgui.new.char[128]("")

chatLog = {}
currentNearbyNames = {}
currentNearbyIDs = {}
nearbyComboItems = ffi.new('const char*[1]')
nearbyPointers = { imgui.new.char[256]("Yakinda oyuncu bulunamadi") }
nearbyComboItems[0] = nearbyPointers[1]

lastNearbyUpdate = 0
seciliChatTarget = imgui.new.int(0)
chatMesajInput = imgui.new.char[256]("")
chatLogCount = imgui.new.int(mainIni.ayarlar.chatlog_count or 1)

function match_trim(str, pattern)
    local res = str:match(pattern)
    if res then return res:match("^%s*(.-)%s*$") end
    return nil
end

ozelButonlar, rpButonlar, animButonlar, radarKelimeler, otoMesajlar = {}, {}, {}, {}, {}
aktifAraclar = {}
comboAracCount = 0
comboAracItems = nil
comboAracPointers = {}
seciliAracIndex = imgui.new.int(0)

tusKuyrugu = {}
renderWindow = imgui.new.bool(false)
mouseAktif = true

inputIsim, inputKomut = imgui.new.char[256](""), imgui.new.char[256]("")
inputRpIsim, inputRpKomut = imgui.new.char[256](""), imgui.new.char[256]("")
inputAnimIsim, inputAnimKomut = imgui.new.char[256](""), imgui.new.char[256]("")
inputRadar = imgui.new.char[128]("")

otoIsim = imgui.new.char[128]("")
otoKomut = imgui.new.char[256]("")
otoGun = imgui.new.int(0)
otoSaat = imgui.new.int(0)
otoDakika = imgui.new.int(5)
otoSaniye = imgui.new.int(0)

seciliFontIndex = imgui.new.int(mainIni.ayarlar.secili_font or 0)
seciliKisayol = imgui.new.int(mainIni.ayarlar.kisayol_v2 or vkeys.VK_F2)
seciliMouseKisayol = imgui.new.int(mainIni.ayarlar.mouse_kisayol_v2 or vkeys.VK_MBUTTON)
temaRengi = imgui.new.float[3](mainIni.ayarlar.tema_r or 0.20, mainIni.ayarlar.tema_g or 0.55, mainIni.ayarlar.tema_b or 0.95)
temaYuvarlaklik = imgui.new.float(mainIni.ayarlar.yuvarlaklik or 8.0)
mouseTip = imgui.new.int(mainIni.ayarlar.mouse_tip or 1)
sesVeEfektAktif = imgui.new.bool(mainIni.ayarlar.ses_ve_efekt)
rgbBorder = imgui.new.bool(mainIni.ayarlar.rgb_border or false)
animArkaplan = imgui.new.int(mainIni.ayarlar.anim_arkaplan or 0)
kameraSabitleAktif = imgui.new.bool(mainIni.ayarlar.kamera_sabitle or false)

beklePanelTusu, bekleMouseTusu = false, false
bindGecikmesi = 0

afkAktif = imgui.new.bool(mainIni.afk.aktif or false)
afkTetikleyici = imgui.new.char[128](mainIni.afk.tetikleyici or "Kullanici")
afkMesaj = imgui.new.char[256](mainIni.afk.mesaj or "Su an klavye basinda degilim, daha sonra donus yapacagim.")

aksanAktif = imgui.new.bool(mainIni.rol_filtre.aksan_aktif or false)
aksanMetin = imgui.new.char[128](mainIni.rol_filtre.aksan_metin or "[Ispanyolca] ")
telsizAktif = imgui.new.bool(mainIni.rol_filtre.telsiz_aktif or false)

otoKemerAktif = imgui.new.bool(mainIni.oto_arac.kemer or false)
otoMotorAktif = imgui.new.bool(mainIni.oto_arac.motor or false)

seciliHava = imgui.new.int(0)
seciliSaat = imgui.new.int(12)

calcMiktar1 = imgui.new.int(0)
calcMiktar2 = imgui.new.int(0)
calcSonuc = 0

ajandaDosya = getWorkingDirectory() .. "\\SAMP_Ajanda.txt"
ajandaBuffer = imgui.new.char[16384]("")

duzenleRpIndex, duzenleOzelIndex, duzenleAnimIndex = 0, 0, 0
sidebarMenuler = {
    "Ana Sayfa", "Karakter Profili", "Oturum Istatistikleri", "Canli Sohbet", 
    "Oto-Mesaj Botu", "Arac Kontrolleri", "RP Asistani", "Animasyonlar", 
    "Not Defteri", "Hesap Kitap", "Atmosfer Ayari", "Blackjack (Zar)", 
    "Ozel Kisayollar", "Moduller", "Tema ve Gorunum"
}
seciliSekme = imgui.new.int(1)

particles = {}
bgParticles = {}

for i = 1, 50 do
    table.insert(bgParticles, {
        x = math.random() * 2000, y = math.random() * 2000,
        speed = 0.5 + math.random() * 1.5, size = 1.0 + math.random() * 2.0,
        phase = math.random() * math.pi * 2
    })
end

function AnimButton(isim, beklemeBoyutu)
    local btnBoyut = beklemeBoyutu or imgui.ImVec2(0, 0)
    local clicked = imgui.Button(isim, btnBoyut)
    if imgui.IsItemHovered() then
        local dl = imgui.GetWindowDrawList()
        local min = imgui.GetItemRectMin()
        local max = imgui.GetItemRectMax()
        min.x = min.x - 2; min.y = min.y - 2
        max.x = max.x + 2; max.y = max.y + 2
        
        local r, g, b = temaRengi[0], temaRengi[1], temaRengi[2]
        if rgbBorder[0] then
            local time = os.clock() * 2.0
            r = (math.sin(time) + 1.0) * 0.5; g = (math.sin(time + 2.0) + 1.0) * 0.5; b = (math.sin(time + 4.0) + 1.0) * 0.5
        end
        local c = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, 0.6))
        dl:AddRect(min, max, c, temaYuvarlaklik[0], 0, 2.0)
    end
    if clicked and sesVeEfektAktif[0] then addOneOffSound(0, 0, 0, 1083) end
    return clicked
end

function updateAracCombo()
    local list = {}
    if #aktifAraclar == 0 then 
        table.insert(list, "Cevrede arac bulunamadi (Yenile)")
    else
        for i, v in ipairs(aktifAraclar) do 
            table.insert(list, string.format("%s (ID: %d) - Plaka: %s", v.isim, v.id, v.plaka)) 
        end
    end
    
    comboAracCount = #list
    if comboAracCount > 0 then
        comboAracItems = ffi.new('const char*[?]', comboAracCount)
    else
        comboAracItems = ffi.new('const char*[1]')
    end
    
    comboAracPointers = {} 
    for i, v in ipairs(list) do
        comboAracPointers[i] = imgui.new.char[256](v)
        comboAracItems[i - 1] = comboAracPointers[i]
    end
    seciliAracIndex[0] = 0 
end

function ajandaYukle()
    local f = io.open(ajandaDosya, "r")
    if f then ffi.copy(ajandaBuffer, f:read("*a")); f:close() end
end

function ajandaKaydet()
    local f = io.open(ajandaDosya, "w")
    if f then f:write(ffi.string(ajandaBuffer)); f:close(); sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Notlar basariyla kaydedildi.", -1) end
end

function animasyonlariYukle()
    local f = io.open(animDosya, "r")
    animButonlar = {}
    if f then
        for line in f:lines() do
            local isim, komut = line:match("([^|]+)|([^|]+)")
            if isim and komut then
                table.insert(animButonlar, {isim = isim, komut = komut})
            end
        end
        f:close()
    else
        local newF = io.open(animDosya, "w")
        if newF then
            newF:write("Otur|/otur 1\nEl Salla|/anim salla\n")
            newF:close()
            animButonlar = {{isim="Otur", komut="/otur 1"}, {isim="El Salla", komut="/anim salla"}}
        end
    end
end

function animasyonlariKaydet()
    local f = io.open(animDosya, "w")
    if f then
        for i, v in ipairs(animButonlar) do
            f:write(v.isim .. "|" .. v.komut .. "\n")
        end
        f:close()
    end
end

function ayarlariYukle()
    ozelButonlar, rpButonlar, radarKelimeler, otoMesajlar = {}, {}, {}, {}
    if mainIni.isimler then for k, v in pairs(mainIni.isimler) do if mainIni.komutlar[k] then table.insert(ozelButonlar, {isim = v, komut = mainIni.komutlar[k]}) end end end
    if mainIni.rp_isimler then for k, v in pairs(mainIni.rp_isimler) do if mainIni.rp_komutlar[k] then table.insert(rpButonlar, {isim = v, komut = mainIni.rp_komutlar[k]}) end end end
    if mainIni.radar then for k, v in pairs(mainIni.radar) do table.insert(radarKelimeler, v) end end
    
    if mainIni.oto_mesajlar then
        for k, v in pairs(mainIni.oto_mesajlar) do
            local parts = {}
            for p in string.gmatch(v, "([^|]+)") do table.insert(parts, p) end
            if #parts >= 6 then
                table.insert(otoMesajlar, {
                    isim = parts[1], komut = parts[2], gun = tonumber(parts[3]), saat = tonumber(parts[4]),
                    dakika = tonumber(parts[5]), saniye = tonumber(parts[6]), aktif = false, sonraki_zaman = 0
                })
            end
        end
    end
    
    animasyonlariYukle()
    updateAracCombo(); ajandaYukle()
end

function ayarlariKaydet()
    local y = {isimler = {}, komutlar = {}, rp_isimler = {}, rp_komutlar = {}, radar = {}, oto_mesajlar = {}, ayarlar = {}, afk = {}, rol_filtre = {}, oto_arac = {}}
    for i, val in ipairs(ozelButonlar) do y.isimler[tostring(i)] = val.isim; y.komutlar[tostring(i)] = val.komut end
    for i, val in ipairs(rpButonlar) do y.rp_isimler[tostring(i)] = val.isim; y.rp_komutlar[tostring(i)] = val.komut end
    for i, val in ipairs(radarKelimeler) do y.radar[tostring(i)] = val end
    for i, val in ipairs(otoMesajlar) do y.oto_mesajlar[tostring(i)] = string.format("%s|%s|%d|%d|%d|%d", val.isim, val.komut, val.gun, val.saat, val.dakika, val.saniye) end
    
    y.ayarlar.kisayol_v2 = seciliKisayol[0]; y.ayarlar.mouse_kisayol_v2 = seciliMouseKisayol[0]; y.ayarlar.secili_font = seciliFontIndex[0]
    y.ayarlar.tema_r = temaRengi[0]; y.ayarlar.tema_g = temaRengi[1]; y.ayarlar.tema_b = temaRengi[2]
    y.ayarlar.yuvarlaklik = temaYuvarlaklik[0]; y.ayarlar.mouse_tip = mouseTip[0]; y.ayarlar.ses_ve_efekt = sesVeEfektAktif[0]
    y.ayarlar.rgb_border = rgbBorder[0]; y.ayarlar.anim_arkaplan = animArkaplan[0]; y.ayarlar.kamera_sabitle = kameraSabitleAktif[0]
    y.ayarlar.chatlog_count = chatLogCount[0]
    
    y.afk.aktif = afkAktif[0]; y.afk.tetikleyici = ffi.string(afkTetikleyici); y.afk.mesaj = ffi.string(afkMesaj)
    y.rol_filtre.aksan_aktif = aksanAktif[0]; y.rol_filtre.aksan_metin = ffi.string(aksanMetin); y.rol_filtre.telsiz_aktif = telsizAktif[0]
    y.oto_arac.kemer = otoKemerAktif[0]; y.oto_arac.motor = otoMotorAktif[0]
    
    inicfg.save(y, iniFile); mainIni = inicfg.load(nil, iniFile)
    animasyonlariKaydet()
end

if sampev_yuklu then
    function sampev.onSendChat(message)
        sesLastActive = os.clock()
        sesMsgCount = sesMsgCount + 1
        local yollanacak = message
        
        if telsizAktif[0] and yollanacak:sub(1,1) ~= "/" then yollanacak = "/t " .. yollanacak end
        
        if aksanAktif[0] then
            local prefix = u8_decode(ffi.string(aksanMetin))
            if prefix ~= "" and yollanacak:sub(1,3) ~= "/b " and yollanacak:sub(1,4) ~= "/pm " then
                if yollanacak:sub(1,3) == "/t " then yollanacak = "/t " .. prefix .. yollanacak:sub(4)
                elseif yollanacak:sub(1,3) == "/r " then yollanacak = "/r " .. prefix .. yollanacak:sub(4)
                elseif yollanacak:sub(1,3) == "/f " then yollanacak = "/f " .. prefix .. yollanacak:sub(4)
                elseif yollanacak:sub(1,1) ~= "/" then yollanacak = prefix .. yollanacak end
            end
        end
        if yollanacak ~= message then return { yollanacak } end
    end
    
    function sampev.onSendWeaponsUpdate()
        if isCharShooting(PLAYER_PED) then sesShotsFired = sesShotsFired + 1 end
    end

    function sampev.onSendCommand(cmd)
        sesLastActive = os.clock()
        if cmd == "/arac liste" then aktifAraclar = {}; updateAracCombo() end
        
        local colorMatch, msgMatch = cmd:match("^/fchat (%x%x%x%x%x%x) (.+)")
        if colorMatch and msgMatch then
            sampAddChatMessage(msgMatch, tonumber("0xFF"..colorMatch, 16))
            return false
        end
    end
    
    function sampev.onServerMessage(color, text)
        local temizMetin = text:gsub("{%x%x%x%x%x%x}", "")
        
        local noTimeText = temizMetin:gsub("^%[%d%d:%d%d:%d%d%]%s*", "")
        local lowerNoTime = noTimeText:lower()
        local isWhisper = lowerNoTime:find("f.s.lda") or lowerNoTime:find("f.s.lt")
        
        local isMeDo = temizMetin:match("^%* ")
        local isPlayerChat = temizMetin:match("^[A-Z]%a+_[A-Z]%a+:") or temizMetin:match("^[A-Z]%a+ [A-Z]%a+:") or temizMetin:match("^[A-Z]%w+:")
        local isPM = temizMetin:find("%(%( << ") or temizMetin:find("%(%( >> ") or temizMetin:find("%[PM%]") or temizMetin:find("PM %-")
        
        if isMeDo or isPlayerChat or isPM or isWhisper then
            table.insert(chatLog, { txt = u8(temizMetin), raw = text:gsub("{%x%x%x%x%x%x}", "") })
            if #chatLog > 200 then table.remove(chatLog, 1) end 
        end
        
        if temizMetin:find("Aktif %- ") then
            local model, id, plaka = temizMetin:match("Aktif %- (.-)%s*%((%d+)%) %- Plaka: (.-) %-")
            if model and id and plaka then table.insert(aktifAraclar, {isim = model, id = tonumber(id), plaka = plaka}); updateAracCombo() end
        end
        
        local z1, z2, pName = temizMetin:match("%* Cift zar atti ve (%d+),%s*(%d+) geldi%. %(%(%s*(.-)%s*%)%)")
        if z1 and z2 and pName then
            if not bjData[pName] then table.insert(bjPlayers, pName); bjData[pName] = { toplam = 0, tekli = 0, ciftli = 0 } end
            bjData[pName].toplam = bjData[pName].toplam + tonumber(z1) + tonumber(z2)
            bjData[pName].tekli = bjData[pName].tekli + 2
            bjData[pName].ciftli = bjData[pName].ciftli + 1
        end
        
        local zTek, pNameTek = temizMetin:match("%* Tek zar atti ve (%d+) geldi%. %(%(%s*(.-)%s*%)%)")
        if not zTek then zTek, pNameTek = temizMetin:match("%* Zar atti ve (%d+) geldi%. %(%(%s*(.-)%s*%)%)") end
        
        if zTek and pNameTek then
            if not bjData[pNameTek] then table.insert(bjPlayers, pNameTek); bjData[pNameTek] = { toplam = 0, tekli = 0, ciftli = 0 } end
            bjData[pNameTek].toplam = bjData[pNameTek].toplam + tonumber(zTek)
            bjData[pNameTek].tekli = bjData[pNameTek].tekli + 1
        end
        
        if temizMetin:find("Karakter:") and temizMetin:find("Seviye:") then
            charStats.isim = match_trim(temizMetin, "Karakter:%s*([^|]+)") or charStats.isim
            charStats.seviye = match_trim(temizMetin, "Seviye:%s*([^|]+)") or charStats.seviye
            charStats.exp = match_trim(temizMetin, "EXP:%s*([^|]+)") or charStats.exp
        elseif temizMetin:find("Cinsiyet:") and temizMetin:find("Do.um Tarihi:") then
            charStats.cinsiyet = match_trim(temizMetin, "Cinsiyet:%s*([^|]+)") or charStats.cinsiyet
            charStats.dogum = match_trim(temizMetin, "Do.um Tarihi:%s*([^|]+)") or charStats.dogum
        elseif temizMetin:find("SQLID:") then
            charStats.para = match_trim(temizMetin, "Para:%s*([^|]+)") or charStats.para
            charStats.saat = match_trim(temizMetin, "Oynama Saati:%s*([^|]+)") or charStats.saat
            charStats.birlik = match_trim(temizMetin, "Birlik:%s*([^|]+)") or charStats.birlik
            charStats.rutbe = match_trim(temizMetin, "R.tbe:%s*(.+)") or charStats.rutbe
        elseif temizMetin:find("Telefon Numaras.:") then
            charStats.telefon = match_trim(temizMetin, "Telefon Numaras.:%s*([^|]+)") or charStats.telefon
            charStats.banka = match_trim(temizMetin, "Banka Hesab.:%s*([^|]+)") or charStats.banka
        elseif temizMetin:find("Ba.ıml.l.k:") or temizMetin:find("Can:") then
            charStats.can = match_trim(temizMetin, "Can:%s*([^|]+)") or charStats.can
            charStats.zirh = match_trim(temizMetin, "Z.rh:%s*([^|]+)") or charStats.zirh
            charStats.meslek = match_trim(temizMetin, "Meslek:%s*(.+)") or charStats.meslek
        elseif temizMetin:find("Market Bakiyesi:") then
            charStats.market = match_trim(temizMetin, "Market Bakiyesi:%s*([^|]+)") or charStats.market
            charStats.vip = match_trim(temizMetin, "VIP Durumu:%s*([^|]+)") or charStats.vip
        elseif temizMetin:find("Payday:") then
            charStats.payday = match_trim(temizMetin, "Payday:%s*([^|]+)") or charStats.payday
            charStats.maas = match_trim(temizMetin, "Maa.:%s*([^|]+)") or charStats.maas
        elseif temizMetin:find("Medeni Durum:") then
            charStats.medeni = match_trim(temizMetin, "Medeni Durum:%s*([^|]+)") or charStats.medeni
            charStats.es = match_trim(temizMetin, "E.i:%s*([^|]+)") or charStats.es
        elseif temizMetin:find("Vatanda.l.k Numaras.:") then
            charStats.tc_no = match_trim(temizMetin, "Vatanda.l.k Numaras.:%s*(.+)") or charStats.tc_no
        elseif temizMetin:find("Uyruk / K.ken:") then
            charStats.uyruk = match_trim(temizMetin, "Uyruk / K.ken:%s*(.+)") or charStats.uyruk
        elseif temizMetin:find("^%s*Ehliyet:") and not temizMetin:find("%[") then
            charStats.ehliyet = match_trim(temizMetin, "Ehliyet:%s*(.+)") or charStats.ehliyet
        elseif temizMetin:find("^%s*U.u. Lisans.:") then
            charStats.ucus = match_trim(temizMetin, "U.u. Lisans.:%s*(.+)") or charStats.ucus
        elseif temizMetin:find("^%s*Silah Ta..ma Lisans.:") then
            charStats.silah = match_trim(temizMetin, "Silah Ta..ma Lisans.:%s*(.+)") or charStats.silah
        end
        
        local kendiMesaji = false
        local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if res then
            local myName = sampGetPlayerNickname(myId)
            if myName then
                local myNameSpaced = myName:gsub("_", " ")
                if temizMetin:find("^%* " .. myNameSpaced) or temizMetin:find("^" .. myNameSpaced .. ":") then kendiMesaji = true end
            end
        end
        
        if not kendiMesaji and not temizMetin:find("%[Radar%]") then
            local lower_text = temizMetin:lower()
            for _, kelime in ipairs(radarKelimeler) do
                if kelime ~= "" and lower_text:find(kelime:lower()) then
                    addOneOffSound(0, 0, 0, 1057)
                    sampAddChatMessage(string.format("{FF0000}[Radar] {FFFFFF}Belirtilen kelime sohbette algilandi ({FFFF00}%s{FFFFFF}): %s", kelime, temizMetin), -1)
                    break 
                end
            end
        end
        
        if afkAktif[0] then
            local tetikKelime = ffi.string(afkTetikleyici)
            if tetikKelime ~= "" and temizMetin:find(tetikKelime) and not temizMetin:find("%[AFK%]") then
                local sender_id = temizMetin:match("%((%d+)%)")
                if sender_id then lua_thread.create(function() wait(1200); sampSendChat(string.format("/pm %s [AFK] %s", sender_id, u8_decode(ffi.string(afkMesaj)))) end) end
            end
        end
    end
end

function ModernTemaUygula()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    
    local r, g, b = temaRengi[0], temaRengi[1], temaRengi[2]
    
    if rgbBorder[0] then
        local time = os.clock() * 2.0
        r = (math.sin(time) + 1.0) * 0.5
        g = (math.sin(time + 2.0) + 1.0) * 0.5
        b = (math.sin(time + 4.0) + 1.0) * 0.5
        style.WindowBorderSize = 2.0 
    else
        style.WindowBorderSize = 1.0
    end

    local rnd = temaYuvarlaklik[0]
    style.WindowRounding, style.PopupRounding, style.ChildRounding, style.TabRounding = rnd, rnd, rnd, rnd
    style.FrameRounding = rnd / 1.5
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.ItemSpacing = imgui.ImVec2(10, 8)
    style.ScrollbarRounding = rnd
    style.ScrollbarSize = 12.0

    if animArkaplan[0] ~= 0 or bgTexture then
        colors[clr.WindowBg] = ImVec4(0.06, 0.06, 0.08, 0.55) 
    else
        colors[clr.WindowBg] = ImVec4(0.12, 0.12, 0.14, 0.96)
    end
    
    colors[clr.Border] = ImVec4(r, g, b, 0.8) 
    colors[clr.ChildBg] = ImVec4(0.15, 0.15, 0.17, 0.6)
    colors[clr.FrameBg] = ImVec4(0.20, 0.20, 0.22, 0.85)
    colors[clr.FrameBgHovered] = ImVec4(0.26, 0.26, 0.28, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.32, 0.32, 0.35, 1.00)
    
    colors[clr.Button] = ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 0.7)
    colors[clr.ButtonHovered] = ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 0.9)
    colors[clr.ButtonActive] = ImVec4(temaRengi[0] - 0.1, temaRengi[1] - 0.1, temaRengi[2] - 0.1, 1.0)
    
    colors[clr.Text] = ImVec4(0.95, 0.95, 0.95, 1.00)
    colors[clr.PlotHistogram] = ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0)
end

local function DrawStat(label, val, offset, colorObj)
    local off = offset or 140
    imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), label .. ":")
    imgui.SameLine(off) 
    
    local c = colorObj or imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0)
    if not colorObj then
        if val == "Yok" or val == "Issiz" then c = imgui.ImVec4(0.9, 0.3, 0.3, 1.0)
        elseif val == "Mevcut" then c = imgui.ImVec4(0.3, 0.9, 0.4, 1.0) end
    end
    
    imgui.TextColored(c, tostring(val))
end

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        ModernTemaUygula()
        
        if bootState == 1 or bootState == 2 then 
            player.HideCursor = true 
        else
            player.HideCursor = not mouseAktif
        end
        
        local currentTime = os.clock()
        
        if bootState == 1 or bootState == 2 then
            local gecenSure = currentTime - bootStartTime
            local sw, sh = getScreenResolution()
            imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(400, 200), imgui.Cond.Always)
            
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.05, 0.05, 0.05, 0.95))
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 15.0)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 1.0)
            
            imgui.Begin("BootScreen", renderWindow, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove)
            
            if fontAktif then imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1]) end
            
            if bootState == 1 then
                if gecenSure < 3.0 then
                    local alpha = math.abs(math.sin(gecenSure * 3))
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], alpha))
                    
                    local text = "Sistem Yukleniyor..."
                    local tSize = imgui.CalcTextSize(text)
                    
                    imgui.SetCursorPos(imgui.ImVec2((400 - tSize.x)/2, (200 - tSize.y)/2))
                    imgui.Text(text)
                    
                    imgui.PopStyleColor()
                else
                    bootState = 2
                    bootStartTime = os.clock()
                end
            elseif bootState == 2 then
                if gecenSure < 3.0 then
                    local alpha = (gecenSure < 1.5) and (gecenSure / 1.5) or (1.0 - ((gecenSure - 1.5) / 1.5))
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 1.0, 1.0, alpha))
                    
                    local text = "Made By Jakuzi"
                    local tSize = imgui.CalcTextSize(text)
                    
                    imgui.SetCursorPos(imgui.ImVec2((400 - (tSize.x * 1.5))/2, (200 - (tSize.y * 1.5))/2))
                    imgui.SetWindowFontScale(1.5)
                    imgui.Text(text)
                    imgui.SetWindowFontScale(1.0)
                    
                    imgui.PopStyleColor()
                else
                    bootState = 3
                    animState = 1
                end
            end
            
            if fontAktif then imgui.PopFont() end
            
            imgui.End()
            imgui.PopStyleVar(2)
            imgui.PopStyleColor()
            return 
        end

        if animState == 1 then
            animProgress = animProgress + 0.08
            if animProgress >= 1.0 then 
                animProgress = 1.0
                animState = 2 
            end
        elseif animState == 3 then
            animProgress = animProgress - 0.08
            if animProgress <= 0.0 then 
                animProgress = 0.0
                animState = 0
                renderWindow[0] = false
                mouseAktif = false
                return
            end
        end

        local targetAlpha = mouseAktif and 1.0 or 0.5
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, animProgress * targetAlpha)

        if mouseTip[0] ~= 0 then
            imgui.GetIO().MouseDrawCursor = true
            imgui.SetMouseCursor(imgui.MouseCursor.None)
            local foreDrawList = imgui.GetForegroundDrawList()
            local mx, my = imgui.GetMousePos().x, imgui.GetMousePos().y
            local c = imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], animProgress))
            local cOut = imgui.GetColorU32Vec4(imgui.ImVec4(0, 0, 0, animProgress))
            
            if mouseTip[0] == 1 then
                foreDrawList:AddTriangleFilled(imgui.ImVec2(mx, my), imgui.ImVec2(mx+15, my+5), imgui.ImVec2(mx+5, my+15), c)
                foreDrawList:AddTriangle(imgui.ImVec2(mx, my), imgui.ImVec2(mx+15, my+5), imgui.ImVec2(mx+5, my+15), cOut, 1.5)
            elseif mouseTip[0] == 2 then
                foreDrawList:AddCircleFilled(imgui.ImVec2(mx, my), 5.0, c)
                foreDrawList:AddCircle(imgui.ImVec2(mx, my), 6.0, cOut, 0, 1.5)
            elseif mouseTip[0] == 3 then
                foreDrawList:AddLine(imgui.ImVec2(mx-10, my), imgui.ImVec2(mx+10, my), c, 2.0)
                foreDrawList:AddLine(imgui.ImVec2(mx, my-10), imgui.ImVec2(mx, my+10), c, 2.0)
            end
        else
            imgui.GetIO().MouseDrawCursor = false 
        end

        local foreDrawList = imgui.GetForegroundDrawList()
        if sesVeEfektAktif[0] and imgui.IsMouseClicked(0) and imgui.IsWindowHovered(imgui.HoveredFlags.AnyWindow) then
            local mx, my = imgui.GetMousePos().x, imgui.GetMousePos().y
            for i = 1, 15 do
                table.insert(particles, { x = mx, y = my, vx = (math.random() - 0.5) * 8.0, vy = (math.random() - 0.5) * 8.0, life = 1.0, max_life = 1.0 + (math.random() * 0.5) })
            end
        end
        for i = #particles, 1, -1 do
            local p = particles[i]
            p.x = p.x + p.vx; p.y = p.y + p.vy; p.life = p.life - 0.03
            if p.life <= 0 then table.remove(particles, i)
            else
                local c = imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], (p.life / p.max_life) * animProgress))
                foreDrawList:AddCircleFilled(imgui.ImVec2(p.x, p.y), 3.0 * p.life, c)
            end
        end

        local fontAktifState = false
        if fontComboCount > 0 and mevcutFontPointers[seciliFontIndex[0] + 1] then
            imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1])
            fontAktifState = true
        end

        imgui.SetNextWindowPos(imgui.ImVec2(350, 200), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(980, 680), imgui.Cond.FirstUseEver)
        
        imgui.Begin("Modern HUB - Kontrol Sende", renderWindow, imgui.WindowFlags.NoCollapse)
        
        local bgDrawList = imgui.GetWindowDrawList()
        local wPos = imgui.GetWindowPos()
        local wSize = imgui.GetWindowSize()
        
        if bgTexture then
            bgDrawList:AddImage(bgTexture, wPos, imgui.ImVec2(wPos.x + wSize.x, wPos.y + wSize.y))
        else
            if animArkaplan[0] > 0 then 
                local cTema = imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 0.3 * animProgress))
                local cBeyaz = imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 1.0, 0.3 * animProgress))
                local cMavi = imgui.GetColorU32Vec4(imgui.ImVec4(0.5, 0.8, 1.0, 0.3 * animProgress))
                
                for _, p in ipairs(bgParticles) do
                    if animArkaplan[0] == 1 then
                        p.y = p.y + p.speed
                        if p.y > wSize.y then p.y = 0; p.x = math.random() * wSize.x end
                        bgDrawList:AddCircleFilled(imgui.ImVec2(wPos.x + p.x, wPos.y + p.y), p.size, cBeyaz)
                    elseif animArkaplan[0] == 2 then
                        p.y = p.y + (p.speed * 2.5)
                        if p.y > wSize.y then p.y = 0; p.x = math.random() * wSize.x end
                        bgDrawList:AddRectFilled(imgui.ImVec2(wPos.x + p.x, wPos.y + p.y), imgui.ImVec2(wPos.x + p.x + 2, wPos.y + p.y + p.size * 5), cTema)
                    elseif animArkaplan[0] == 3 then
                        p.y = p.y + (p.speed * 0.8)
                        p.phase = p.phase + 0.02
                        local sway = math.sin(p.phase) * 1.5
                        if p.y > wSize.y then p.y = 0; p.x = math.random() * wSize.x end
                        bgDrawList:AddCircleFilled(imgui.ImVec2(wPos.x + p.x + sway, wPos.y + p.y), p.size * 1.2, cBeyaz)
                    elseif animArkaplan[0] == 4 then
                        p.y = p.y - (p.speed * 1.2)
                        p.phase = p.phase + 0.03
                        local sway = math.cos(p.phase) * 2.0
                        if p.y < 0 then p.y = wSize.y; p.x = math.random() * wSize.x end
                        bgDrawList:AddCircle(imgui.ImVec2(wPos.x + p.x + sway, wPos.y + p.y), p.size * 3.0, cMavi, 0, 1.5)
                    elseif animArkaplan[0] == 5 then
                        p.y = p.y + (p.speed * 3.0)
                        p.x = p.x - (p.speed * 3.0)
                        if p.y > wSize.y or p.x < 0 then p.y = 0; p.x = wSize.x + (math.random() * 500) end
                        bgDrawList:AddLine(imgui.ImVec2(wPos.x + p.x, wPos.y + p.y), imgui.ImVec2(wPos.x + p.x + p.size*10, wPos.y + p.y - p.size*10), cTema, 2.0)
                    end
                end
            end
        end

        imgui.BeginChild("Sidebar", imgui.ImVec2(220, 0), true)
        imgui.Dummy(imgui.ImVec2(0, 5))
        for i, isim in ipairs(sidebarMenuler) do
            if seciliSekme[0] == i then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 0.8))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0))
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.3, 0.3, 0.4))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.4, 0.4, 0.4, 0.6))
            end
            
            if AnimButton(isim, imgui.ImVec2(-1, 40)) then seciliSekme[0] = i end
            imgui.PopStyleColor(3)
        end
        imgui.EndChild()
        
        imgui.SameLine()
        
        imgui.BeginChild("Content", imgui.ImVec2(0, 0), true)
        
        if seciliSekme[0] == 1 then
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Modern Arayuz Paneli - Ana Sayfa")
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "SAMP icin gelistirilmis cok amacli kontrol ve otomasyon arayuzu.")
            imgui.Dummy(imgui.ImVec2(0, 20))

            imgui.Columns(2, "AnaSayfaSutunlar", false)
            imgui.SetColumnWidth(0, 450)

            imgui.BeginChild("SistemDurumu", imgui.ImVec2(0, 120), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Sistem Durumu")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if sampev_yuklu then
                imgui.TextColored(imgui.ImVec4(0.2, 0.8, 0.3, 1.0), "[ AKTIF ]")
                imgui.SameLine()
                imgui.Text("Tum moduller ve SAMP.Lua entegrasyonu sorunsuz calisiyor.")
            else
                imgui.TextColored(imgui.ImVec4(0.9, 0.2, 0.2, 1.0), "[ UYARI ]")
                imgui.SameLine()
                imgui.Text("SAMP.Lua kutuphanesi eksik. Bazi islevler calismayabilir.")
            end
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Guncel Versiyon: v" .. SURUM)
            imgui.EndChild()

            imgui.BeginChild("YapimciBilgileri", imgui.ImVec2(0, 160), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Yapimci & Iletisim")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            DrawStat("Yapimci", "Jakuzi", 150, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0))
            DrawStat("Discord", "reyax.", 150, imgui.ImVec4(0.4, 0.4, 0.9, 1.0))

            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Discord Sunucusu:")
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.4, 0.8, 0.5))
            if imgui.Button("https://discord.gg/gMDEtNw5ac", imgui.ImVec2(-1, 30)) then
                os.execute("start https://discord.gg/gMDEtNw5ac")
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text("Linki tarayicida acmak icin tiklayin.")
                imgui.EndTooltip()
            end
            imgui.PopStyleColor()
            imgui.EndChild()

            imgui.NextColumn()

            imgui.BeginChild("HizliBilgiler", imgui.ImVec2(0, 295), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Panele Genel Bakis")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextWrapped("Bu panel, rol yapma (RP) sunucularinda ve genel SAMP kullaniminda islerinizi hizlandirmak uzere tasarlanmistir. Tum moduller entegre ve optimize sekilde calisir.")
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "One Cikan Ozellikler:")
            imgui.BulletText("Otomatik Mesaj & Reklam Botu")
            imgui.BulletText("Etkilesimli Canli Sohbet Logu")
            imgui.BulletText("Kapsamli Blackjack & Zar Hesaplayici")
            imgui.BulletText("Cevresel Oyuncu ve Arac Algilama")
            imgui.BulletText("Dinamik Tema ve Animasyon Yonetimi")
            imgui.EndChild()

            imgui.Columns(1)

        elseif seciliSekme[0] == 2 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Karakter Profili ve Durumu")
            BilgiKutusu("Oyun ici karakter ve lisans bilgilerinizi anlik olarak listeler.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if AnimButton("Bilgileri Yenile (/karakter)", imgui.ImVec2(220, 35)) then sampSendChat("/karakter") end
            imgui.SameLine()
            if AnimButton("Kimligi Goster (/kimlikgoster)", imgui.ImVec2(220, 35)) then 
                local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if res then sampSendChat("/kimlikgoster " .. myId) end
            end
            imgui.SameLine()
            if AnimButton("Lisanslari Goster (/ehliyetgoster)", imgui.ImVec2(-1, 35)) then 
                local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if res then sampSendChat("/ehliyetgoster " .. myId) end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.Columns(2, "CharStatsColumns", false)
            
            imgui.BeginChild("KisiselBilgiler", imgui.ImVec2(0, 215), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Kisisel Bilgiler")
            imgui.Separator()
            DrawStat("Isim", charStats.isim, 140)
            DrawStat("Vatandaslik No", charStats.tc_no, 140)
            DrawStat("Uyruk", charStats.uyruk, 140)
            DrawStat("Cinsiyet", charStats.cinsiyet, 140)
            DrawStat("Dogum Tarihi", charStats.dogum, 140)
            DrawStat("Medeni Durum", charStats.medeni, 140)
            DrawStat("Es", charStats.es, 140)
            DrawStat("Telefon", charStats.telefon, 140)
            imgui.EndChild()

            imgui.BeginChild("KariyerBilgileri", imgui.ImVec2(0, 155), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Kariyer & Birlik")
            imgui.Separator()
            DrawStat("Seviye", charStats.seviye, 140)
            DrawStat("EXP", charStats.exp, 140)
            DrawStat("Oynama Saati", charStats.saat, 140)
            DrawStat("Birlik", charStats.birlik, 140)
            DrawStat("Rutbe", charStats.rutbe, 140)
            DrawStat("Meslek", charStats.meslek, 140)
            imgui.EndChild()

            imgui.NextColumn()
            
            imgui.BeginChild("EkonomiBilgileri", imgui.ImVec2(0, 155), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Ekonomi & Varlik")
            imgui.Separator()
            DrawStat("Nakit Para", charStats.para, 140)
            DrawStat("Banka Hesabi", charStats.banka, 140)
            DrawStat("Market Bakiye", charStats.market, 140)
            DrawStat("VIP Durumu", charStats.vip, 140)
            DrawStat("Payday Suresi", charStats.payday, 140)
            DrawStat("Maas Suresi", charStats.maas, 140)
            imgui.EndChild()

            imgui.BeginChild("SaglikBilgileri", imgui.ImVec2(0, 110), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Saglik & Durum Grafigi")
            imgui.Separator()
            
            local hpStr = charStats.can:gsub(",", ".")
            local hpNum = tonumber(hpStr) or 0
            local arStr = charStats.zirh:gsub(",", ".")
            local arNum = tonumber(arStr) or 0

            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Can Durumu:")
            imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
            imgui.ProgressBar(math.min(1.0, hpNum / 100.0), imgui.ImVec2(-1, 20), tostring(hpNum))
            imgui.PopStyleColor()

            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Zirh Durumu:")
            imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.7, 0.7, 0.7, 1.0))
            imgui.ProgressBar(math.min(1.0, arNum / 100.0), imgui.ImVec2(-1, 20), tostring(arNum))
            imgui.PopStyleColor()
            imgui.EndChild()
            
            imgui.BeginChild("LisansBilgileri", imgui.ImVec2(0, 95), true)
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Lisans & Belgeler")
            imgui.Separator()
            DrawStat("Ehliyet", charStats.ehliyet, 140)
            DrawStat("Ucus Lisansi", charStats.ucus, 140)
            DrawStat("Silah Ruhsati", charStats.silah, 140)
            imgui.EndChild()
            imgui.Columns(1)

        elseif seciliSekme[0] == 3 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Oturum Istatistikleri & Arkaplan Verileri")
            BilgiKutusu("Mevcut oturumdaki fiziksel aktiviteleri ve finansal verileri gosterir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            local runTime = os.time() - sesStartT
            local saat = math.floor(runTime / 3600)
            local dk = math.floor((runTime % 3600) / 60)
            
            imgui.BeginChild("SesStatKutu", imgui.ImVec2(0, 0), true)
            imgui.Columns(2, "StatsCol", false)
            imgui.SetColumnWidth(0, 350)
            
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Zaman & Etkilesim")
            imgui.Separator()
            DrawStat("Gecen Sure", string.format("%d saat, %d dakika", saat, dk), 200)
            DrawStat("AFK Kalinan Sure", string.format("%d dakika", math.floor(sesAfkTime / 60)), 200)
            DrawStat("Sohbete Yazilanlar", tostring(sesMsgCount) .. " mesaj", 200)
            DrawStat("Ateslenen Mermi", tostring(sesShotsFired) .. " el", 200)
            DrawStat("Görülen Oyuncular", tostring(#sesPlayersSeen) .. " kisi", 200)
            
            imgui.NextColumn()
            
            imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Fiziksel & Ekonomik Veriler")
            imgui.Separator()
            DrawStat("Yaya Gidilen Mesafe", string.format("%.2f km", sesFootDist / 1000.0), 200)
            DrawStat("Aracla Gidilen Mesafe", string.format("%.2f km", sesCarDist / 1000.0), 200)
            DrawStat("Maksimum Hiz", string.format("%.1f km/h", sesMaxSpeed), 200, imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
            DrawStat("Binilen Araclar", tostring(sesCarsUsed) .. " adet", 200)
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            DrawStat("Kazanilan Ciro", "$" .. formatNumber(sesMoneyEarned), 200, imgui.ImVec4(0.3, 0.9, 0.4, 1.0))
            DrawStat("Kaybedilen Para", "$" .. formatNumber(sesMoneyLost), 200, imgui.ImVec4(0.9, 0.3, 0.3, 1.0))
            
            imgui.Columns(1)
            imgui.EndChild()

        elseif seciliSekme[0] == 4 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Canli & Etkilesimli Rol Logu")
            BilgiKutusu("Sohbet gecmisini kaydetmenizi veya kopyalamanizi saglar. Islem icin satira sag tiklayin.")
            
            imgui.SameLine(imgui.GetWindowContentRegionWidth() - 250)
            if AnimButton("Sohbeti Not Defterine Kaydet", imgui.ImVec2(250, 25)) then
                local path = getWorkingDirectory() .. "\\chatlog" .. chatLogCount[0] .. ".txt"
                local f = io.open(path, "w")
                if f then
                    f:write("--- CHATLOG " .. chatLogCount[0] .. " ---\n")
                    for _, log in ipairs(chatLog) do f:write(log.raw .. "\n") end
                    f:close()
                    sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Sohbet " .. path .. " adresine kaydedildi.", -1)
                    chatLogCount[0] = chatLogCount[0] + 1
                    ayarlariKaydet()
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.BeginChild("ChatHistory", imgui.ImVec2(0, -45), true)
            for i, log in ipairs(chatLog) do
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 15)
                imgui.TextUnformatted(log.txt)
                imgui.PopTextWrapPos()
                
                if imgui.BeginPopupContextItem("ChatIslem##"..i) then
                    if imgui.Button("Bu Satiri Kopyala") then
                        imgui.SetClipboardText(u8_decode(log.raw))
                        sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Satir panoya kopyalandi.", -1)
                        imgui.CloseCurrentPopup()
                    end
                    imgui.EndPopup()
                end
                
                imgui.GetWindowDrawList():AddLine(
                    imgui.ImVec2(imgui.GetCursorScreenPos().x, imgui.GetCursorScreenPos().y),
                    imgui.ImVec2(imgui.GetCursorScreenPos().x + imgui.GetWindowWidth() - 30, imgui.GetCursorScreenPos().y),
                    imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.05)), 1.0
                )
                imgui.Dummy(imgui.ImVec2(0, 2))
            end
            if imgui.GetScrollY() >= imgui.GetScrollMaxY() then imgui.SetScrollHereY(1.0) end
            imgui.EndChild()
            
            imgui.PushItemWidth(180)
            if #currentNearbyNames > 0 then
                imgui.Combo("##NearbyChat", seciliChatTarget, nearbyComboItems, #currentNearbyNames)
            else
                imgui.Combo("##NearbyChat", seciliChatTarget, nearbyComboItems, 1)
            end
            imgui.PopItemWidth()
            
            imgui.SameLine()
            imgui.PushItemWidth(250)
            imgui.InputText("Mesaj Yaz", chatMesajInput, 256)
            imgui.PopItemWidth()
            
            imgui.SameLine()
            if AnimButton("PM At", imgui.ImVec2(75, 25)) then
                if #currentNearbyIDs > 0 then
                    local tid = currentNearbyIDs[seciliChatTarget[0] + 1]
                    local msg = ffi.string(chatMesajInput)
                    if msg ~= "" then sampSendChat("/pm " .. tid .. " " .. u8_decode(msg)); ffi.copy(chatMesajInput, "") end
                end
            end
            imgui.SameLine()
            if AnimButton("Fisilda", imgui.ImVec2(75, 25)) then
                if #currentNearbyIDs > 0 then
                    local tid = currentNearbyIDs[seciliChatTarget[0] + 1]
                    local msg = ffi.string(chatMesajInput)
                    if msg ~= "" then sampSendChat("/w " .. tid .. " " .. u8_decode(msg)); ffi.copy(chatMesajInput, "") end
                end
            end

        elseif seciliSekme[0] == 5 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Otomatik Mesaj (Bot) Ayarlari")
            BilgiKutusu("Belirtilen sure araliklarinda arka planda otomatik mesaj veya komut gonderir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.BeginChild("OtoEkle", imgui.ImVec2(0, 130), true)
            imgui.PushItemWidth(150)
            imgui.InputText("Isim Belirle", otoIsim, 128)
            imgui.SameLine()
            imgui.PushItemWidth(350)
            imgui.InputText("Gonderilecek Icerik (/ ile)", otoKomut, 256)
            imgui.PopItemWidth(); imgui.PopItemWidth()
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushItemWidth(100)
            imgui.SliderInt("Gun", otoGun, 0, 7)
            imgui.SameLine()
            imgui.SliderInt("Saat", otoSaat, 0, 23)
            imgui.SameLine()
            imgui.SliderInt("Dakika", otoDakika, 0, 59)
            imgui.SameLine()
            imgui.SliderInt("Saniye", otoSaniye, 0, 59)
            imgui.PopItemWidth()
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            if AnimButton("Yeni Islem Ekle", imgui.ImVec2(-1, 30)) then
                local isimS = ffi.string(otoIsim)
                local komS = ffi.string(otoKomut)
                if isimS ~= "" and komS ~= "" then
                    if otoGun[0] == 0 and otoSaat[0] == 0 and otoDakika[0] == 0 and otoSaniye[0] == 0 then
                        sampAddChatMessage("{FF0000}[Uyari] {FFFFFF}Lutfen gecerli bir sure ayarlayiniz.", -1)
                    else
                        table.insert(otoMesajlar, {
                            isim = isimS, komut = komS, gun = otoGun[0], saat = otoSaat[0], 
                            dakika = otoDakika[0], saniye = otoSaniye[0], aktif = false, sonraki_zaman = 0
                        })
                        ayarlariKaydet()
                        ffi.copy(otoIsim, ""); ffi.copy(otoKomut, "")
                        otoGun[0]=0; otoSaat[0]=0; otoDakika[0]=5; otoSaniye[0]=0
                    end
                end
            end
            imgui.EndChild()
            
            imgui.Separator()
            imgui.BeginChild("OtoListe", imgui.ImVec2(0, 0), true)
            if #otoMesajlar == 0 then
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Aktif bir otomatik mesaj botu bulunmamaktadir.")
            else
                for i, v in ipairs(otoMesajlar) do
                    local dl = imgui.GetWindowDrawList()
                    local cp = imgui.GetCursorScreenPos()
                    
                    local statusColor = v.aktif and imgui.GetColorU32Vec4(imgui.ImVec4(0.2, 0.8, 0.3, 1.0)) or imgui.GetColorU32Vec4(imgui.ImVec4(0.9, 0.2, 0.2, 1.0))
                    dl:AddCircleFilled(imgui.ImVec2(cp.x + 15, cp.y + 15), 8.0, statusColor)
                    
                    imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPos().x + 35, imgui.GetCursorPos().y + 5))
                    imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), string.format("%s (Tekrar: %dG %dS %dD %dSn)", v.isim, v.gun, v.saat, v.dakika, v.saniye))
                    
                    imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 170, imgui.GetCursorPos().y - 30))
                    
                    if AnimButton((v.aktif and "Durdur##" or "Baslat##") .. i, imgui.ImVec2(80, 25)) then
                        v.aktif = not v.aktif
                        if v.aktif then
                            v.sonraki_zaman = os.time() + (v.gun * 86400) + (v.saat * 3600) + (v.dakika * 60) + v.saniye
                            sampAddChatMessage("{4A90E2}[Bot] {FFFFFF}" .. v.isim .. " botu aktif edildi.", -1)
                        else
                            sampAddChatMessage("{4A90E2}[Bot] {FFFFFF}" .. v.isim .. " botu durduruldu.", -1)
                        end
                        ayarlariKaydet()
                    end
                    
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if AnimButton("Sil##otodelete"..i, imgui.ImVec2(50, 25)) then
                        table.remove(otoMesajlar, i)
                        ayarlariKaydet()
                    end
                    imgui.PopStyleColor()
                    
                    imgui.Dummy(imgui.ImVec2(0, 10))
                    imgui.Separator()
                end
            end
            imgui.EndChild()

        elseif seciliSekme[0] == 6 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Garaj & Arac Kontrolleri")
            BilgiKutusu("Arac fonksiyonlarinin uzaktan veya iceriden hizli yonetimini saglar.")
            
            imgui.BeginChild("KilitKutusu", imgui.ImVec2(0, 140), true)
            if AnimButton("Cevredeki Araclari Tara [ /arac liste ]", imgui.ImVec2(-1, 35)) then sampSendChat("/arac liste") end
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushItemWidth(300)
            if comboAracCount > 0 then imgui.Combo("##AracSecici", seciliAracIndex, comboAracItems, comboAracCount)
            else local d = ffi.new('const char*[1]', {ffi.cast("const char*", "Cevrede arac bulunamadi")}); imgui.Combo("##AracSecici", seciliAracIndex, d, 1) end
            imgui.PopItemWidth()
            
            imgui.SameLine()
            if AnimButton("Kilitle / Ac", imgui.ImVec2(120, 30)) then
                if #aktifAraclar > 0 then sampSendChat("/akilit " .. tostring(aktifAraclar[seciliAracIndex[0] + 1].id)) end
            end
            imgui.SameLine()
            if AnimButton("Konumu Bul (GPS)", imgui.ImVec2(120, 30)) then
                if #aktifAraclar > 0 then sampSendChat("/agps " .. tostring(aktifAraclar[seciliAracIndex[0] + 1].id)) end
            end
            imgui.EndChild()
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.BeginChild("AracDisiKontrol", imgui.ImVec2(0, 125), true)
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Arac Disi")
            imgui.Separator()
            if AnimButton("Yanindaki Araci Kilitle / Ac [ N Tusu ]", imgui.ImVec2(-1, 30)) then table.insert(tusKuyrugu, vkeys.VK_N) end
            imgui.Dummy(imgui.ImVec2(0, 2))
            if AnimButton("Kaputu Ac", imgui.ImVec2(150, 30)) then sampSendChat("/arac kaput") end imgui.SameLine()
            if AnimButton("Bagaji Ac", imgui.ImVec2(150, 30)) then sampSendChat("/arac bagaj") end imgui.SameLine()
            if AnimButton("Park Et", imgui.ImVec2(100, 30)) then sampSendChat("/park") end imgui.SameLine()
            if AnimButton("Sakla", imgui.ImVec2(100, 30)) then sampSendChat("/arac sakla") end
            imgui.EndChild()
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            if isCharInAnyCar(PLAYER_PED) then
                imgui.BeginChild("AracIciKontrol", imgui.ImVec2(0, 0), true)
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Icerideki Kontroller ve Hasar Durumu")
                imgui.Separator()
                
                local car = storeCarCharIsInNoSave(PLAYER_PED)
                local hPercent = math.max(0, math.min(1, (getCarHealth(car) - 250) / 750))
                
                imgui.Columns(2, "CarCols", false)
                imgui.SetColumnWidth(0, 340)
                
                imgui.Text("Arac Genel Durumu:")
                imgui.ProgressBar(hPercent, imgui.ImVec2(310, 20), string.format("Saglamlik: %d%%", math.floor(hPercent * 100)))
                imgui.Dummy(imgui.ImVec2(0, 5))
                if AnimButton("Motoru Calistir / Durdur [ Y ]", imgui.ImVec2(310, 35)) then table.insert(tusKuyrugu, vkeys.VK_Y) end 
                if AnimButton("Farlari Yak / Sondur [ N ]", imgui.ImVec2(310, 35)) then table.insert(tusKuyrugu, vkeys.VK_N) end 
                if AnimButton("Kapilari Iceriden Kilitle", imgui.ImVec2(310, 35)) then sampSendChat("/arac kilit") end
                imgui.Dummy(imgui.ImVec2(0, 5))
                if imgui.Checkbox("Surus Kamerasini Sabitle", kameraSabitleAktif) then ayarlariKaydet() end
                BilgiKutusu("Arac kullanimi sirasinda kamera sarsintilarini devre disi birakir.")
                
                imgui.NextColumn()
                
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Canli Hasar Sensoru")
                
                local dl = imgui.GetWindowDrawList()
                local p = imgui.GetCursorScreenPos()
                local cx, cy = p.x + 80, p.y + 70
                
                local cGreen = imgui.GetColorU32Vec4(imgui.ImVec4(0.2, 0.8, 0.3, 1.0))
                local cRed = imgui.GetColorU32Vec4(imgui.ImVec4(0.9, 0.2, 0.2, 1.0))
                local cBody = imgui.GetColorU32Vec4(imgui.ImVec4(0.25, 0.25, 0.3, 1.0))
                local cWin = imgui.GetColorU32Vec4(imgui.ImVec4(0.1, 0.1, 0.12, 1.0))
                local cText = imgui.GetColorU32Vec4(imgui.ImVec4(0.7, 0.7, 0.7, 1.0))
                
                local fl = isCarTireBurst(car, 0); local rl = isCarTireBurst(car, 1)
                local fr = isCarTireBurst(car, 2); local rr = isCarTireBurst(car, 3)
                
                local function tC(b) return b and cRed or cGreen end
                
                dl:AddRectFilled(imgui.ImVec2(cx - 30, cy - 60), imgui.ImVec2(cx + 30, cy + 60), cBody, 8.0)
                dl:AddRect(imgui.ImVec2(cx - 30, cy - 60), imgui.ImVec2(cx + 30, cy + 60), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.2)), 8.0, 0, 1.5)
                dl:AddRectFilled(imgui.ImVec2(cx - 24, cy - 25), imgui.ImVec2(cx + 24, cy + 30), cWin, 4.0)
                
                dl:AddRectFilled(imgui.ImVec2(cx - 42, cy - 45), imgui.ImVec2(cx - 30, cy - 15), tC(fl), 4.0)
                dl:AddRectFilled(imgui.ImVec2(cx + 30, cy - 45), imgui.ImVec2(cx + 42, cy - 15), tC(fr), 4.0)
                dl:AddRectFilled(imgui.ImVec2(cx - 42, cy + 15), imgui.ImVec2(cx - 30, cy + 45), tC(rl), 4.0)
                dl:AddRectFilled(imgui.ImVec2(cx + 30, cy + 15), imgui.ImVec2(cx + 42, cy + 45), tC(rr), 4.0)
                
                local eC = (hPercent > 0.5) and cGreen or ((hPercent > 0.25) and imgui.GetColorU32Vec4(imgui.ImVec4(0.9, 0.8, 0.2, 1.0)) or cRed)
                dl:AddCircleFilled(imgui.ImVec2(cx, cy - 40), 6.0, eC)
                
                dl:AddLine(imgui.ImVec2(cx + 8, cy - 40), imgui.ImVec2(cx + 60, cy - 40), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.3)), 1.0)
                dl:AddText(imgui.ImVec2(cx + 65, cy - 47), cText, "Motor")
                
                dl:AddLine(imgui.ImVec2(cx + 42, cy - 30), imgui.ImVec2(cx + 60, cy - 10), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.3)), 1.0)
                dl:AddText(imgui.ImVec2(cx + 65, cy - 17), cText, "On Lastik")
                
                dl:AddLine(imgui.ImVec2(cx + 42, cy + 30), imgui.ImVec2(cx + 60, cy + 10), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.3)), 1.0)
                dl:AddText(imgui.ImVec2(cx + 65, cy + 3), cText, "Arka Lastik")
                
                imgui.Dummy(imgui.ImVec2(0, 160))
                imgui.Columns(1)
                
                imgui.EndChild()
            else
                imgui.TextColored(imgui.ImVec4(0.9, 0.3, 0.3, 1.0), "Arac ici ayarlarini kullanabilmek icin bir aracta olmalisiniz.")
            end

        elseif seciliSekme[0] == 7 then
            imgui.BeginChild("RPAyarKutusu", imgui.ImVec2(0, 195), true)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Rol Komutlarini Ayarla")
            BilgiKutusu("Yakindaki oyuncularla hizli etkilesim kurmanizi saglar. Formatta {isim} ve {id} degiskenleri kullanilabilir.")
            imgui.Dummy(imgui.ImVec2(0, 2))
            
            imgui.PushItemWidth(140)
            imgui.InputText("Isim", inputRpIsim, 256)
            imgui.SameLine()
            imgui.PushItemWidth(250)
            imgui.InputText("Komut", inputRpKomut, 256)
            imgui.PopItemWidth()
            imgui.PopItemWidth()
            
            imgui.SameLine()
            if duzenleRpIndex == 0 then
                if AnimButton("Ekle##rpekle", imgui.ImVec2(75, 27)) then
                    local isimStr, komutStr = ffi.string(inputRpIsim), ffi.string(inputRpKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        table.insert(rpButonlar, {isim = isimStr, komut = komutStr})
                        ayarlariKaydet(); ffi.copy(inputRpIsim, ""); ffi.copy(inputRpKomut, "")
                    end
                end
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
                if AnimButton("Guncelle", imgui.ImVec2(75, 27)) then
                    local isimStr, komutStr = ffi.string(inputRpIsim), ffi.string(inputRpKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        rpButonlar[duzenleRpIndex].isim = isimStr; rpButonlar[duzenleRpIndex].komut = komutStr
                        ayarlariKaydet(); duzenleRpIndex = 0; ffi.copy(inputRpIsim, ""); ffi.copy(inputRpKomut, "")
                    end
                end
                imgui.PopStyleColor()
            end
            
            imgui.Separator()
            if #rpButonlar == 0 then imgui.TextColored(imgui.ImVec4(0.8, 0.3, 0.3, 1.0), "Henuz bir veri eklenmemis.")
            else
                for i, val in ipairs(rpButonlar) do
                    imgui.TextColored(imgui.ImVec4(0.4, 0.8, 1.0, 1.0), val.isim)
                    imgui.SameLine(140)
                    local kisaKomut = val.komut
                    if #kisaKomut > 40 then kisaKomut = kisaKomut:sub(1, 40) .. "..." end
                    imgui.Text(kisaKomut)
                    
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 95) 
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
                    if AnimButton("Duzenle##rpduz"..i, imgui.ImVec2(65, 22)) then
                        duzenleRpIndex = i; ffi.copy(inputRpIsim, val.isim); ffi.copy(inputRpKomut, val.komut)
                    end
                    imgui.PopStyleColor()
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if AnimButton("X##rpsil"..i, imgui.ImVec2(25, 22)) then
                        if duzenleRpIndex == i then duzenleRpIndex = 0; ffi.copy(inputRpIsim, ""); ffi.copy(inputRpKomut, "") end
                        table.remove(rpButonlar, i); ayarlariKaydet()
                    end
                    imgui.PopStyleColor()
                end
            end
            imgui.EndChild()
            
            imgui.Text("Menzildeki Oyuncular (15 Metre Capi)")
            imgui.Separator()
            imgui.BeginChild("RP_Listesi", imgui.ImVec2(0, 0), true)
            local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
            local oyuncuBulundu = false
            for _, ped in ipairs(getAllChars()) do
                if ped ~= PLAYER_PED then
                    local isPlayer, id = sampGetPlayerIdByCharHandle(ped)
                    if isPlayer then
                        local px, py, pz = getCharCoordinates(ped)
                        local dist = getDistanceBetweenCoords3d(myX, myY, myZ, px, py, pz)
                        if dist <= 15.0 then
                            oyuncuBulundu = true
                            local name = sampGetPlayerNickname(id):gsub("_", " ")
                            imgui.TextColored(imgui.ImVec4(0.4, 0.8, 1.0, 1.0), string.format("[%d] %s", id, name))
                            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), string.format("Mesafe: %.1f metre", dist))
                            
                            for i, b in ipairs(rpButonlar) do
                                if AnimButton(b.isim .. "##b"..id.."_"..i, imgui.ImVec2(130, 30)) then
                                    local finalCmd = b.komut:gsub("{isim}", name):gsub("{id}", tostring(id))
                                    sampSendChat(u8_decode(finalCmd))
                                end
                                if i % 4 ~= 0 and i ~= #rpButonlar then imgui.SameLine() end
                            end
                            if #rpButonlar > 0 then imgui.Dummy(imgui.ImVec2(0, 5)) end
                            imgui.Separator()
                        end
                    end
                end
            end
            if not oyuncuBulundu then imgui.TextColored(imgui.ImVec4(0.8, 0.3, 0.3, 1.0), "Cevrede islem yapilabilecek oyuncu bulunamadi.") end
            imgui.EndChild()

        elseif seciliSekme[0] == 8 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Animasyon Studyosu")
            BilgiKutusu("Kayitli animasyonlari tek tikla uygulamanizi saglar. Veriler harici metin dosyasinda saklanir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushItemWidth(180)
            imgui.InputText("Animasyon Adi", inputAnimIsim, 256)
            imgui.SameLine(320)
            imgui.InputText("Komut (/ ile)", inputAnimKomut, 256)
            imgui.PopItemWidth()
            
            if duzenleAnimIndex == 0 then
                if AnimButton("Listeye Ekle##animEkle", imgui.ImVec2(-1, 35)) then
                    local isimStr, komutStr = ffi.string(inputAnimIsim), ffi.string(inputAnimKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        table.insert(animButonlar, {isim = isimStr, komut = komutStr})
                        animasyonlariKaydet(); ffi.copy(inputAnimIsim, ""); ffi.copy(inputAnimKomut, "")
                    end
                end
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
                if AnimButton("Guncelle##animGuncelle", imgui.ImVec2(-1, 35)) then
                    local isimStr, komutStr = ffi.string(inputAnimIsim), ffi.string(inputAnimKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        animButonlar[duzenleAnimIndex].isim = isimStr; animButonlar[duzenleAnimIndex].komut = komutStr
                        animasyonlariKaydet(); duzenleAnimIndex = 0; ffi.copy(inputAnimIsim, ""); ffi.copy(inputAnimKomut, "")
                    end
                end
                imgui.PopStyleColor()
            end
            
            imgui.Separator()
            imgui.BeginChild("AnimKutu", imgui.ImVec2(0, 0), true)
            
            if #animButonlar == 0 then imgui.TextColored(imgui.ImVec4(0.8, 0.3, 0.3, 1.0), "Liste su an bos.")
            else
                for i, val in ipairs(animButonlar) do
                    if AnimButton(val.isim .. "##btn_anim" .. i, imgui.ImVec2(440, 40)) then sampSendChat(u8_decode(val.komut)) end
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 110)
                    
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
                    if AnimButton("Duzenle##animduz"..i, imgui.ImVec2(70, 40)) then
                        duzenleAnimIndex = i; ffi.copy(inputAnimIsim, val.isim); ffi.copy(inputAnimKomut, val.komut)
                    end
                    imgui.PopStyleColor()
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if AnimButton("X##animsil" .. i, imgui.ImVec2(35, 40)) then
                        if duzenleAnimIndex == i then duzenleAnimIndex = 0; ffi.copy(inputAnimIsim, ""); ffi.copy(inputAnimKomut, "") end
                        table.remove(animButonlar, i); animasyonlariKaydet()
                    end
                    imgui.PopStyleColor()
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.Separator()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
            if AnimButton("Tum Animasyonlari Durdur [ /dans ]", imgui.ImVec2(-1, 45)) then sampSendChat("/dans") end
            imgui.PopStyleColor()
            imgui.EndChild()

        elseif seciliSekme[0] == 9 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Sahsi Not Defteri")
            BilgiKutusu("Oyun ici alinan notlari SAMP_Ajanda.txt dosyasina kaydeder.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
            if AnimButton("Degisiklikleri Kaydet", imgui.ImVec2(180, 30)) then ajandaKaydet() end
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "(Degisiklikleri kaydetmeyi unutmayiniz)")
            imgui.Separator()
            imgui.InputTextMultiline("##ajandainput", ajandaBuffer, ffi.sizeof(ajandaBuffer), imgui.ImVec2(-1, 500))

        elseif seciliSekme[0] == 10 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Hesaplama Yonetimi")
            BilgiKutusu("Oyun ici temel matematiksel islemleri gerceklestirir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.BeginChild("CalcKutu", imgui.ImVec2(0, 250), true)
            
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Guncel Sonuc:")
            
            if fontComboCount > 0 and mevcutFontPointers[seciliFontIndex[0] + 1] then imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1]) end
            imgui.TextColored(imgui.ImVec4(0.3, 0.9, 0.4, 1.0), string.format("$ %s", formatNumber(math.floor(calcSonuc))))
            if fontComboCount > 0 and mevcutFontPointers[seciliFontIndex[0] + 1] then imgui.PopFont() end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.PushItemWidth(250)
            imgui.InputInt("1. Deger", calcMiktar1)
            imgui.InputInt("2. Deger", calcMiktar2)
            imgui.PopItemWidth()
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if AnimButton("Topla (+)", imgui.ImVec2(110, 35)) then calcSonuc = calcMiktar1[0] + calcMiktar2[0] end
            imgui.SameLine()
            if AnimButton("Cikar (-)", imgui.ImVec2(110, 35)) then calcSonuc = calcMiktar1[0] - calcMiktar2[0] end
            imgui.SameLine()
            if AnimButton("Carp (x)", imgui.ImVec2(110, 35)) then calcSonuc = calcMiktar1[0] * calcMiktar2[0] end
            imgui.SameLine()
            if AnimButton("Bol (/)", imgui.ImVec2(110, 35)) then 
                if calcMiktar2[0] ~= 0 then calcSonuc = calcMiktar1[0] / calcMiktar2[0] else calcSonuc = 0 end 
            end
            imgui.EndChild()

        elseif seciliSekme[0] == 11 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Atmosfer ve Zaman Ayarlari")
            BilgiKutusu("Gorus mesafesi, saat ve hava durumu gibi yerel cevre ayarlarini degistirir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.BeginChild("AtmoKutu", imgui.ImVec2(0, 100), true)
            imgui.TextColored(imgui.ImVec4(0.4, 0.8, 1.0, 1.0), "Gorus Mesafesi (Draw Distance)")
            
            if AnimButton("Performans Modu (FPS)", imgui.ImVec2(180, 35)) then
                ffi.cast("float*", 0x8DCE38)[0] = 300.0
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Gorus mesafesi performans modu icin dusuruldu.", -1)
            end
            imgui.SameLine()
            if AnimButton("Ultra Gorus (SS Modu)", imgui.ImVec2(180, 35)) then
                ffi.cast("float*", 0x8DCE38)[0] = 3000.0
                forceWeatherNow(1) 
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Gorus mesafesi maksimum seviyeye cikarildi.", -1)
            end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
            if AnimButton("Varsayilana Don", imgui.ImVec2(-1, 35)) then
                ffi.cast("float*", 0x8DCE38)[0] = 800.0
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Gorus mesafesi varsayilan degere donduruldu.", -1)
            end
            imgui.PopStyleColor()
            imgui.EndChild()
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.BeginChild("ZamanKutu", imgui.ImVec2(0, 0), true)
            
            imgui.TextColored(imgui.ImVec4(0.9, 0.8, 0.2, 1.0), "Zaman Birimi Ayari")
            imgui.PushItemWidth(350)
            imgui.SliderInt("Istenilen Saat", seciliSaat, 0, 23)
            imgui.PopItemWidth()
            
            if AnimButton("Zamani Sabitle", imgui.ImVec2(200, 35)) then
                g_SabitZaman = seciliSaat[0]
                patch_samp_time_set(true)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Zaman basariyla sabitlendi.", -1)
            end
            imgui.SameLine()
            if AnimButton("Sunucu Senkronizasyonu", imgui.ImVec2(200, 35)) then
                g_SabitZaman = nil
                patch_samp_time_set(false)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Zaman ayari sunucu ile senkronize edildi.", -1)
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            imgui.TextColored(imgui.ImVec4(0.4, 0.8, 1.0, 1.0), "Hava Durumu Modeli")
            imgui.PushItemWidth(350)
            imgui.Combo("Atmosfer Secimi", seciliHava, havaDurumuItems, #havaDurumuIsimleri)
            imgui.PopItemWidth()
            
            if AnimButton("Hava Durumunu Uygula", imgui.ImVec2(200, 35)) then
                local hedefID = havaDurumuIDs[seciliHava[0] + 1]
                forceWeatherNow(hedefID)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Hava durumu basariyla degistirildi.", -1)
            end
            imgui.EndChild()

        elseif seciliSekme[0] == 12 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Blackjack & Zar Asistani")
            BilgiKutusu("Sohbetteki zar verilerini okuyarak oyuncu puanlarini listeler ve 21'i gecme riskini hesaplar.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if AnimButton("Cift Zar At (/zar cift)", imgui.ImVec2(180, 35)) then sampSendChat("/zar cift") end
            imgui.SameLine()
            if AnimButton("Tek Zar At (/zar tek)", imgui.ImVec2(180, 35)) then sampSendChat("/zar tek") end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
            if AnimButton("Verileri Temizle (Yeni El)", imgui.ImVec2(-1, 35)) then bjPlayers = {}; bjData = {} end
            imgui.PopStyleColor()
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.BeginChild("ZarMasasi", imgui.ImVec2(0, 0), true)
            
            if #bjPlayers == 0 then
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Henuz zar atilmadi, veriler bekleniyor...")
            else
                for i, pName in ipairs(bjPlayers) do
                    local data = bjData[pName]
                    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.12, 0.14, 0.8))
                    imgui.BeginChild("kisi_"..i, imgui.ImVec2(0, 120), true)
                    
                    imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Oyuncu: " .. pName)
                    
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 90)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if AnimButton("Sifirla##" .. i, imgui.ImVec2(80, 25)) then
                        bjData[pName] = nil
                        table.remove(bjPlayers, i)
                    end
                    imgui.PopStyleColor()
                    
                    imgui.Separator()
                    
                    imgui.TextColored(imgui.ImVec4(0.9, 0.9, 0.9, 1.0), "Guncel Puan: ")
                    imgui.SameLine()
                    
                    local cScore = imgui.ImVec4(0.3, 0.9, 0.4, 1.0)
                    local durumMetni = "GUVENLI BOLGE"
                    if data.toplam == 21 then 
                        cScore = imgui.ImVec4(0.9, 0.8, 0.2, 1.0)
                        durumMetni = "BLACKJACK MUKEMMEL"
                    elseif data.toplam > 21 then 
                        cScore = imgui.ImVec4(0.9, 0.3, 0.3, 1.0) 
                        durumMetni = "LIMIT ASIMI (Busted)"
                    elseif data.toplam >= 17 then
                        cScore = imgui.ImVec4(0.9, 0.8, 0.2, 1.0)
                        durumMetni = "RISKLI BOLGE"
                    end
                    
                    imgui.TextColored(cScore, tostring(data.toplam) .. " [" .. durumMetni .. "]")
                    
                    local riskTek = getRiskTekZar(data.toplam)
                    local riskCift = getRiskCiftZar(data.toplam)
                    
                    imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
                    imgui.ProgressBar(riskTek / 100.0, imgui.ImVec2(300, 15), string.format("1 Zarda Puan Asimi Ihtimali: %%%.1f", riskTek))
                    imgui.SameLine()
                    imgui.ProgressBar(riskCift / 100.0, imgui.ImVec2(300, 15), string.format("2 Zarda Puan Asimi Ihtimali: %%%.1f", riskCift))
                    imgui.PopStyleColor()
                    
                    imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), string.format("Atilan Tekli Zar: %d adet | Yapilan Ciftli Atis: %d defa", data.tekli, data.ciftli))
                    
                    imgui.EndChild()
                    imgui.PopStyleColor()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                end
            end
            imgui.EndChild()

        elseif seciliSekme[0] == 13 then
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Ozel Kisayollar ve Komutlar")
            BilgiKutusu("Ozel sunucu komutlarini butonlara atayarak hizli erisim saglar.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushItemWidth(180)
            imgui.InputText("Buton Ismi", inputIsim, 256)
            imgui.SameLine(320)
            imgui.InputText("Calisacak Komut (/ ile)", inputKomut, 256)
            imgui.PopItemWidth()
            
            if duzenleOzelIndex == 0 then
                if AnimButton("Listeye Ekle", imgui.ImVec2(-1, 35)) then
                    local isimStr, komutStr = ffi.string(inputIsim), ffi.string(inputKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        table.insert(ozelButonlar, {isim = isimStr, komut = komutStr})
                        ayarlariKaydet(); ffi.copy(inputIsim, ""); ffi.copy(inputKomut, "")
                    end
                end
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
                if AnimButton("Guncelle", imgui.ImVec2(-1, 35)) then
                    local isimStr, komutStr = ffi.string(inputIsim), ffi.string(inputKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        ozelButonlar[duzenleOzelIndex].isim = isimStr; ozelButonlar[duzenleOzelIndex].komut = komutStr
                        ayarlariKaydet(); duzenleOzelIndex = 0; ffi.copy(inputIsim, ""); ffi.copy(inputKomut, "")
                    end
                end
                imgui.PopStyleColor()
            end
            
            imgui.Separator()
            imgui.BeginChild("ListeKutusu", imgui.ImVec2(0, 0), true) 
            if #ozelButonlar == 0 then imgui.TextColored(imgui.ImVec4(0.8, 0.3, 0.3, 1.0), "Bu alan su an bos.")
            else
                for i, val in ipairs(ozelButonlar) do
                    if AnimButton(val.isim .. "##btn" .. i, imgui.ImVec2(440, 40)) then sampSendChat(u8_decode(val.komut)) end
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 110)
                    
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 1.0))
                    if AnimButton("Duzenle##ozduz"..i, imgui.ImVec2(70, 40)) then
                        duzenleOzelIndex = i; ffi.copy(inputIsim, val.isim); ffi.copy(inputKomut, val.komut)
                    end
                    imgui.PopStyleColor()
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if AnimButton("X##ozsil" .. i, imgui.ImVec2(35, 40)) then
                        if duzenleOzelIndex == i then duzenleOzelIndex = 0; ffi.copy(inputIsim, ""); ffi.copy(inputKomut, "") end
                        table.remove(ozelButonlar, i); ayarlariKaydet()
                    end
                    imgui.PopStyleColor()
                end
            end
            imgui.EndChild()

        elseif seciliSekme[0] == 14 then 
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Moduller ve Ek Sistemler")
            
            if imgui.CollapsingHeader("Yerel Sohbet Similasyonu (Sahte Mesaj)") then
                BilgiKutusu("Yerel sohbete yalnizca sizin gorebileceginiz sahte metinler yazar. Ekran goruntusu almak icin idealdir.")
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Kullanim Formatı: /fchat [Renk Kodu] [Mesaj]")
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Ornek: /fchat C2A2DA * Kullanici sag elini kaldirir.")
            end
            
            if imgui.CollapsingHeader("Sohbet İhbar Radari (Kelime Tarayici)") then
                BilgiKutusu("Belirtilen anahtar kelimeler sohbette gectiginde sesli ve gorsel uyari verir.")
                imgui.Dummy(imgui.ImVec2(0, 5))
                imgui.PushItemWidth(250)
                imgui.InputText("Kelime veya Terim", inputRadar, 128)
                imgui.PopItemWidth()
                imgui.SameLine()
                if AnimButton("Listeye Ekle", imgui.ImVec2(100, 25)) then
                    local rStr = ffi.string(inputRadar)
                    if rStr ~= "" then table.insert(radarKelimeler, rStr); ayarlariKaydet(); ffi.copy(inputRadar, "") end
                end
                
                imgui.BeginChild("RadarKutu", imgui.ImVec2(0, 100), true)
                if #radarKelimeler == 0 then imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), "Henuz veri eklenmemis.")
                else
                    for i, kelime in ipairs(radarKelimeler) do
                        imgui.TextColored(imgui.ImVec4(0.9, 0.8, 0.2, 1.0), "- " .. kelime)
                        imgui.SameLine(imgui.GetWindowContentRegionWidth() - 40)
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                        if AnimButton("X##radarsil"..i, imgui.ImVec2(30, 20)) then table.remove(radarKelimeler, i); ayarlariKaydet() end
                        imgui.PopStyleColor()
                    end
                end
                imgui.EndChild()
            end
            
            if imgui.CollapsingHeader("Mesaj Formatlayici (Telsiz/Aksan)") then
                BilgiKutusu("Normal mesajlarin otomatik olarak telsiz kanalina iletilmesini veya baslarina belirli bir ek getirilmesini saglar.")
                if imgui.Checkbox("Metin On Eki Modunu Aktif Et", aksanAktif) then ayarlariKaydet() end
                imgui.PushItemWidth(200)
                imgui.InputText("Uygulanacak On Ek", aksanMetin, 128)
                imgui.PopItemWidth()
                imgui.SameLine()
                if AnimButton("Metni Kaydet", imgui.ImVec2(100, 25)) then ayarlariKaydet() end
                imgui.Separator()
                if imgui.Checkbox("Normal mesajlari direkt telsiz uzerinden (/t) gonder", telsizAktif) then ayarlariKaydet() end
            end

            if imgui.CollapsingHeader("Otomatik Ozel Mesaj (PM) Yanitlayici") then
                BilgiKutusu("Belirlenen anahtar kelime sohbette gectiginde ozel mesaj yoluyla otomatik yanit verir.")
                if imgui.Checkbox("Modulu Aktif Et", afkAktif) then ayarlariKaydet() end
                imgui.PushItemWidth(150)
                imgui.InputText("Tetikleyici Anahtar Kelime", afkTetikleyici, 128)
                imgui.PopItemWidth()
                imgui.PushItemWidth(350)
                imgui.InputText("Iletilecek Otomatik Yanit", afkMesaj, 256)
                imgui.PopItemWidth()
                if AnimButton("Verileri Kaydet", imgui.ImVec2(200, 30)) then ayarlariKaydet() end
            end
            
            if imgui.CollapsingHeader("Favori Kisiler (Bildirim Radari)") then
                BilgiKutusu("Listeye eklenen oyuncular belirlenen menzile girdiginde sesli uyari verir.")
                imgui.PushItemWidth(150)
                imgui.InputText("Eklenecek Oyuncu", yeniKankaIsim, 128)
                imgui.PopItemWidth()
                imgui.SameLine()
                if AnimButton("Listeye Ekle", imgui.ImVec2(150, 25)) then
                    local ism = ffi.string(yeniKankaIsim)
                    if ism ~= "" then favoritePlayers[ism] = true; ffi.copy(yeniKankaIsim, "") end
                end
                
                imgui.BeginChild("FavKutu", imgui.ImVec2(0, 100), true)
                for name, _ in pairs(favoritePlayers) do
                    imgui.TextColored(imgui.ImVec4(0.9, 0.8, 0.2, 1.0), "⭐ " .. name)
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 40)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.0))
                    if AnimButton("X##favsil_"..name, imgui.ImVec2(30, 20)) then favoritePlayers[name] = nil end
                    imgui.PopStyleColor()
                end
                imgui.EndChild()
            end
            
        elseif seciliSekme[0] == 15 then 
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Tema ve Gorunum Ayarlari")
            BilgiKutusu("Arayuz temasini, renk paletini ve imlec stilini kisisellestirir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.BeginChild("TemaKutu", imgui.ImVec2(0, 330), true)
            
            if imgui.Checkbox("Dinamik RGB Cerceve Efektini Aktif Et", rgbBorder) then ayarlariKaydet() end
            BilgiKutusu("Pencere cercevelerinde surekli renk degistiren RGB animasyonunu aktif eder.")
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Arayuz Yazi Tipi:")
            imgui.PushItemWidth(250)
            if fontComboCount > 0 then
                if imgui.Combo("##FontSecici", seciliFontIndex, fontComboItems, fontComboCount) then ayarlariKaydet() end
            end
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if imgui.Checkbox("Gorsel ve Sesli Etkilesim Efektlerini Ac", sesVeEfektAktif) then ayarlariKaydet() end
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.PushItemWidth(250)
            if imgui.Combo("Imlec Stili", mouseTip, mouseTipItems, 4) then ayarlariKaydet() end
            imgui.PopItemWidth()
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Arka Plan Tasarimi:")
            
            imgui.PushItemWidth(250)
            if imgui.Combo("##ArkaplanSecici", animArkaplan, arkaplanItems, 6) then ayarlariKaydet() end
            imgui.PopItemWidth()
            BilgiKutusu("Harici gorsel (arkaplan.jpg) veya dinamik animasyonlari arka planda oynatir.")

            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Hazir Renk Paletleri:")
            if AnimButton("Gece Mavisi", imgui.ImVec2(120, 30)) then temaRengi[0]=0.20; temaRengi[1]=0.55; temaRengi[2]=0.95; ayarlariKaydet() end imgui.SameLine()
            if AnimButton("Kan Kirmizi", imgui.ImVec2(120, 30)) then temaRengi[0]=0.85; temaRengi[1]=0.20; temaRengi[2]=0.25; ayarlariKaydet() end imgui.SameLine()
            if AnimButton("Zehir Yesili", imgui.ImVec2(120, 30)) then temaRengi[0]=0.25; temaRengi[1]=0.80; temaRengi[2]=0.35; ayarlariKaydet() end imgui.SameLine()
            if AnimButton("Karanlik Mode", imgui.ImVec2(120, 30)) then temaRengi[0]=0.40; temaRengi[1]=0.40; temaRengi[2]=0.45; ayarlariKaydet() end
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Manuel Renk Secimi:")
            if imgui.ColorEdit3("Arayuz Rengi", temaRengi) then ayarlariKaydet() end
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            if imgui.SliderFloat("Kose Yuvarlaklik Degeri", temaYuvarlaklik, 0.0, 20.0, "%.1f") then ayarlariKaydet() end
            imgui.EndChild()
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Kontrol Tusu Yapilandirmasi")
            imgui.BeginChild("KlavyeKutu", imgui.ImVec2(0, 140), true)
            
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Paneli acip kapatmak icin kullanilan kisayol tusu:")
            if AnimButton(beklePanelTusu and "Lutfen bir tusa basiniz..." or string.format("Atanan Tus: %s", getKeyName(seciliKisayol[0])), imgui.ImVec2(250, 30)) then
                beklePanelTusu = true; bekleMouseTusu = false; bindGecikmesi = os.clock() + 0.2
            end
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), "Oyun ici imleci gizlemek icin kullanilan kisayol tusu:")
            if AnimButton(bekleMouseTusu and "Lutfen bir tusa basiniz..." or string.format("Atanan Tus: %s", getKeyName(seciliMouseKisayol[0])), imgui.ImVec2(250, 30)) then
                bekleMouseTusu = true; beklePanelTusu = false; bindGecikmesi = os.clock() + 0.2
            end
            imgui.EndChild()
        end
        imgui.EndChild()

        imgui.End()
        imgui.PopStyleVar() 
        if fontAktifState then imgui.PopFont() end
    end
)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    ayarlariYukle()
    
    -- GÜNCELLEME KONTROLÜ
    otomatikGuncellemeKontrolu()
    
    if sampev_yuklu then sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Modern Arayuz Paneli (v" .. SURUM .. ") yuklendi. Komut: /panel", -1)
    else sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Uyari: SAMP.Lua kutuphanesi eksik. Bazi islevler calismayabilir.", -1) end
    
    sampRegisterChatCommand("panel", function()
        if bootState == 0 then
            bootState = 1
            bootStartTime = os.clock()
            renderWindow[0] = true
        elseif bootState == 3 then
            if animState == 0 or animState == 3 then
                animState = 1
                renderWindow[0] = true
            elseif animState == 2 or animState == 1 then
                animState = 3
            end
        end
        if renderWindow[0] then mouseAktif = true end
    end)
    
    local wasInCar = false
    while true do
        wait(0)
        
        local simdi = os.time()
        for i, v in ipairs(otoMesajlar) do
            if v.aktif and simdi >= v.sonraki_zaman then
                sampSendChat(u8_decode(v.komut))
                v.sonraki_zaman = simdi + (v.gun * 86400) + (v.saat * 3600) + (v.dakika * 60) + v.saniye
            end
        end
        
        if os.clock() - lastNearbyUpdate > 1.0 then
            local tempNames = {}
            local tempIDs = {}
            local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
            for _, ped in ipairs(getAllChars()) do
                if ped ~= PLAYER_PED then
                    local isPlayer, id = sampGetPlayerIdByCharHandle(ped)
                    if isPlayer then
                        local px, py, pz = getCharCoordinates(ped)
                        if getDistanceBetweenCoords3d(myX, myY, myZ, px, py, pz) <= 15.0 then
                            local name = sampGetPlayerNickname(id):gsub("_", " ")
                            table.insert(tempNames, string.format("[%d] %s", id, name))
                            table.insert(tempIDs, id)
                        end
                    end
                end
            end
            currentNearbyNames = tempNames
            currentNearbyIDs = tempIDs
            
            if #tempNames > 0 then
                nearbyComboItems = ffi.new('const char*[?]', #tempNames)
                nearbyPointers = {}
                for i, v in ipairs(tempNames) do
                    nearbyPointers[i] = imgui.new.char[256](v)
                    nearbyComboItems[i-1] = nearbyPointers[i]
                end
            else
                nearbyComboItems = ffi.new('const char*[1]')
                nearbyPointers = { imgui.new.char[256]("Yakinda oyuncu bulunamadi") }
                nearbyComboItems[0] = nearbyPointers[1]
            end
            
            if seciliChatTarget[0] >= #tempNames and #tempNames > 0 then 
                seciliChatTarget[0] = #tempNames - 1 
            elseif #tempNames == 0 then 
                seciliChatTarget[0] = 0 
            end
            lastNearbyUpdate = os.clock()
        end
        
        local cPx, cPy, cPz = getCharCoordinates(PLAYER_PED)
        if cPx ~= 0.0 and sesLastPx ~= 0.0 then
            local pDist = getDistanceBetweenCoords3d(cPx, cPy, cPz, sesLastPx, sesLastPy, sesLastPz)
            if pDist > 0.1 and pDist < 100.0 then 
                sesLastActive = os.clock()
                if isCharInAnyCar(PLAYER_PED) then sesCarDist = sesCarDist + pDist
                else sesFootDist = sesFootDist + pDist end
            end
        end
        sesLastPx, sesLastPy, sesLastPz = cPx, cPy, cPz
        
        if os.clock() - sesLastActive > 60.0 then
            sesAfkTime = sesAfkTime + 1
            wait(1000) 
        end
        
        local cMoney = getPlayerMoney(PLAYER_HANDLE)
        if sesLastMoney ~= 0 then
            if cMoney > sesLastMoney then sesMoneyEarned = sesMoneyEarned + (cMoney - sesLastMoney)
            elseif cMoney < sesLastMoney then sesMoneyLost = sesMoneyLost + (sesLastMoney - cMoney) end
        end
        sesLastMoney = cMoney
        
        for _, ped in ipairs(getAllChars()) do
            if ped ~= PLAYER_PED then
                local isP, pId = sampGetPlayerIdByCharHandle(ped)
                if isP then
                    local dist = getDistanceBetweenCoords3d(cPx, cPy, cPz, getCharCoordinates(ped))
                    if dist <= 15.0 then
                        local nName = sampGetPlayerNickname(pId):gsub("_", " ")
                        if not sesPlayersSeen[nName] then
                            sesPlayersSeen[nName] = true
                        end
                        if favoritePlayers[nName] then
                            local t = os.clock()
                            if t > (favoriteAlerted[nName] or 0) then
                                sampAddChatMessage("{FFD700}[Favori Radari] {FFFFFF}" .. nName .. " yakininizda!", -1)
                                addOneOffSound(0, 0, 0, 1150)
                                favoriteAlerted[nName] = t + 300.0 
                            end
                        end
                    end
                end
            end
        end

        if g_SabitZaman then setTimeOfDay(g_SabitZaman, 0) end
        
        if isCharInAnyCar(PLAYER_PED) then
            if not wasInCar then
                wasInCar = true
                sesCarsUsed = sesCarsUsed + 1
            end
            
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            local speed = getCarSpeed(car) * 3.6 
            if speed > sesMaxSpeed then sesMaxSpeed = speed end
            
            if kameraSabitleAktif[0] then
                ffi.cast("float*", 0xB70118)[0] = 50.0
            end
        else wasInCar = false end
        
        if (beklePanelTusu or bekleMouseTusu) and os.clock() > bindGecikmesi then
            for k, v in pairs(vkeys) do
                if type(k) == "string" and k:sub(1,3) == "VK_" and wasKeyPressed(v) then
                    if v ~= vkeys.VK_ESCAPE then
                        if beklePanelTusu then seciliKisayol[0] = v end
                        if bekleMouseTusu then seciliMouseKisayol[0] = v end
                    end
                    beklePanelTusu, bekleMouseTusu = false, false
                    ayarlariKaydet()
                    break
                end
            end
        end
        
        if #tusKuyrugu > 0 then
            local tus = table.remove(tusKuyrugu, 1)
            setVirtualKeyDown(tus, true)
            wait(50)
            setVirtualKeyDown(tus, false)
        end
        
        if not beklePanelTusu and not bekleMouseTusu then
            if seciliKisayol[0] ~= 0 and wasKeyPressed(seciliKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                if bootState == 0 then
                    bootState = 1
                    bootStartTime = os.clock()
                    renderWindow[0] = true
                elseif bootState == 3 then
                    if animState == 0 or animState == 3 then
                        animState = 1
                        renderWindow[0] = true
                    elseif animState == 2 or animState == 1 then
                        animState = 3
                    end
                end
                if renderWindow[0] then mouseAktif = true end
            end
            
            if renderWindow[0] and seciliMouseKisayol[0] ~= 0 then
                if wasKeyPressed(seciliMouseKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                    mouseAktif = not mouseAktif
                end
            end
        end
    end
end

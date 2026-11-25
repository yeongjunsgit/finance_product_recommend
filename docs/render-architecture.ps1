param([string]$OutputDirectory = $PSScriptRoot)

# Repository-local image generator. Uses Windows fonts and System.Drawing only.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$script:Ink = '#203047'
$script:Muted = '#58677B'
$script:Blue = '#2563EB'

function Brush([string]$Color) {
    return [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
}
function Canvas([int]$Width, [int]$Height) {
    $script:Bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
    $script:Graphics = [System.Drawing.Graphics]::FromImage($script:Bitmap)
    $script:Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $script:Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $script:Graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F7F9FC'))
}
function Label([string]$Value, [float]$X, [float]$Y, [float]$Width, [float]$Height,
    [float]$Size = 25, [string]$Color = $script:Ink, [bool]$Bold = $false, [bool]$Center = $true) {
    $style = [System.Drawing.FontStyle]::Regular
    if ($Bold) { $style = [System.Drawing.FontStyle]::Bold }
    $font = [System.Drawing.Font]::new('Malgun Gothic', $Size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Near
    if ($Center) { $format.Alignment = [System.Drawing.StringAlignment]::Center }
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $paint = Brush $Color
    $script:Graphics.DrawString($Value, $font, $paint, [System.Drawing.RectangleF]::new($X,$Y,$Width,$Height), $format)
    $paint.Dispose(); $font.Dispose(); $format.Dispose()
}
function Frame([float]$X,[float]$Y,[float]$Width,[float]$Height,[string]$Fill,[string]$Stroke,[bool]$Dashed=$false) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $r = 24
    $path.AddArc($X,$Y,$r,$r,180,90)
    $path.AddArc(($X+$Width-$r),$Y,$r,$r,270,90)
    $path.AddArc(($X+$Width-$r),($Y+$Height-$r),$r,$r,0,90)
    $path.AddArc($X,($Y+$Height-$r),$r,$r,90,90)
    $path.CloseFigure()
    $paint = Brush $Fill
    $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($Stroke),2)
    if ($Dashed) { $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
    $script:Graphics.FillPath($paint,$path)
    $script:Graphics.DrawPath($pen,$path)
    $paint.Dispose(); $pen.Dispose(); $path.Dispose()
}
function Card([float]$X,[float]$Y,[float]$Width,[float]$Height,[string]$Kind,[string]$Title,[string]$Body,[bool]$Primary=$false) {
    $fill = '#FFFFFF'; $stroke = '#CAD3DF'; $titleColor = $script:Ink
    if ($Primary) { $fill = '#EAF1FF'; $stroke = $script:Blue; $titleColor = '#1749B0' }
    Frame $X $Y $Width $Height $fill $stroke
    Label $Kind ($X+15) ($Y+15) ($Width-30) 35 20 $script:Muted
    Label $Title ($X+15) ($Y+58) ($Width-30) 65 32 $titleColor $true
    Label $Body ($X+22) ($Y+130) ($Width-44) ($Height-148) 24 $script:Muted
}
function Head([double]$TipX,[double]$TipY,[double]$FromX,[double]$FromY,[string]$Color) {
    $angle = [Math]::Atan2($TipY-$FromY,$TipX-$FromX)
    $length = 15; $half = 7
    $backX = $TipX-$length*[Math]::Cos($angle)
    $backY = $TipY-$length*[Math]::Sin($angle)
    $points = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($TipX,$TipY),
        [System.Drawing.PointF]::new(($backX+$half*[Math]::Sin($angle)),($backY-$half*[Math]::Cos($angle))),
        [System.Drawing.PointF]::new(($backX-$half*[Math]::Sin($angle)),($backY+$half*[Math]::Cos($angle)))
    )
    $paint = Brush $Color
    $script:Graphics.FillPolygon($paint,$points)
    $paint.Dispose()
}
function Route([double[]]$Coordinates,[string]$Color=$script:Muted,[bool]$Both=$false,[bool]$Dashed=$false) {
    $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($Color),3)
    if ($Dashed) { $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
    for ($i=0; $i -lt $Coordinates.Length-2; $i+=2) {
        $script:Graphics.DrawLine($pen,[float]$Coordinates[$i],[float]$Coordinates[$i+1],[float]$Coordinates[$i+2],[float]$Coordinates[$i+3])
    }
    $last = $Coordinates.Length-2
    Head $Coordinates[$last] $Coordinates[$last+1] $Coordinates[$last-2] $Coordinates[$last-1] $Color
    if ($Both) { Head $Coordinates[0] $Coordinates[1] $Coordinates[2] $Coordinates[3] $Color }
    $pen.Dispose()
}
function SaveCanvas([string]$Name) {
    $target = Join-Path $OutputDirectory $Name
    $script:Bitmap.Save($target,[System.Drawing.Imaging.ImageFormat]::Png)
    $script:Graphics.Dispose(); $script:Bitmap.Dispose()
    Write-Output $target
}

Canvas 2200 1380
Label 'AI 금융상품 추천 서비스 | 시스템 컨텍스트' 80 55 2040 85 46 $script:Ink $true $false
Label '서비스를 하나의 시스템으로 보고 사용자·외부 시스템과의 관계를 표현합니다.' 84 145 2030 55 27 $script:Muted $false $false

Card 80 450 370 270 '사람' '사용자' "상황과 목표 설명`n조건 수정·상품 비교"
Card 800 430 580 310 '우리 시스템' 'AI 금융상품 추천 서비스' "대화로 조건을 구체화하고`n공시 기반 후보와 비교 근거 제공`n검증된 공식 가입·상담 링크 안내" $true
Card 1680 230 440 230 '외부 시스템' '금융감독원 Finlife' "금융상품통합비교공시 API`n상품·금리·가입·우대조건 제공"
Card 1680 760 440 230 '외부 시스템' '외부 AI 서비스' "자연어 해석·확인 질문 제안`n검증된 결과에 기반한 설명 생성"
Card 660 1060 610 220 '외부 시스템' '금융회사 공식 웹·앱' "상품 조건 확인 및 가입·상담`n진행 여부·승인 결과는 별도"

Route @(450,510,800,510) $script:Blue
Label '상황 입력 / 조건 수정' 455 440 340 55 24
Route @(800,650,450,650) $script:Blue
Label "추천 / 적용 조건 / 이유`n공식 채널 링크 제공" 455 665 340 85 23
Route @(1380,510,1530,510,1530,345,1680,345) $script:Muted $true
Label "공시 조회 요청`n상품 데이터 수신" 1385 225 285 90 23
Route @(1380,665,1530,665,1530,875,1680,875) $script:Muted $true
Label "해석·설명 요청`n변경 의도·답변 수신" 1385 905 290 90 23
Route @(265,720,265,970,965,970,965,1060) '#078577' $false $true
Label '사용자가 제공된 링크를 눌러 공식 채널로 이동' 340 980 610 55 23 '#08786D'
Label '범례: 파랑 = 우리 시스템과 사용자  ·  회색 = 외부 서비스 연동  ·  초록 점선 = 사용자 이동' 85 1300 2020 45 22 $script:Muted $false $false
SaveCanvas 'system-context.png'

Canvas 2440 1600
Label 'AI 금융상품 추천 서비스 | 내부 논리 구조 초안' 70 45 2300 80 44 $script:Ink $true $false
Label '역할 분담을 보여주는 초안입니다. 각 역할이 별도 서버·프로세스라는 뜻은 아닙니다.' 75 135 2280 55 26 $script:Muted $false $false
Frame 480 230 1430 1230 '#F0F5FF' '#8CA9D8' $true
Label '우리 서비스의 책임 범위' 520 245 700 45 24 '#1749B0' $true $false

Card 50 390 330 230 '사람' '사용자' "상황 입력·조건 수정`n후보 비교·선택"
Card 550 380 420 270 '내부 / 사용자 접점' '상담·비교 화면' "메시지와 후보 표시`n누적 조건 확인·수정`n공식 채널 링크 제공" $true
Card 1220 380 590 300 '내부 / 백엔드' '상담·추천 서버' "상담 맥락·조건 변경 관리`n조건 검증·필터링·계산·정렬`nAI 호출 및 결과 검증" $true
Card 1220 850 590 240 '내부 / 저장소' 'DB' "공시 상품·출처·수집일·공식 링크`n상담 조건·메시지·추천 결과" $true
Card 1220 1210 590 210 '내부 / 백엔드 기능' '상품 수집·갱신 처리' "공시 조회·변환·검증·저장`n추천 서버와 같은 앱에 구현 가능" $true
Card 1990 400 400 230 '외부 시스템' '외부 AI 서비스' "문장 해석·조건 변경 제안`n질문·추천 이유 설명 생성"
Card 1990 1200 400 230 '외부 시스템' 'Finlife API' "금융상품 공시 원천`n가입 채널 URL은 별도 검증"
Card 50 860 380 250 '외부 시스템' '금융회사 공식 채널' "사용자가 링크를 눌러 이동`n공식 웹·앱에서 가입·상담"

Route @(380,495,550,495) $script:Blue $true
Label '입력 / 표시' 378 425 170 45 22
Route @(970,495,1220,495) $script:Blue $true
Label "메시지·조건 변경`n후보·적용 조건·링크" 970 520 250 85 22
Route @(1810,495,1990,495) $script:Muted $true
Label "맥락·후보 전달`n해석·설명 수신" 1812 530 176 90 21
Route @(1515,680,1515,850) $script:Blue $true
Label "상담·조건·결과 저장`n상품·직전 조건 조회" 1550 710 310 95 23
Route @(1515,1210,1515,1090) $script:Blue
Label '검증한 상품 갱신' 1555 1110 300 65 23
Route @(1810,1315,1990,1315) $script:Muted $true
Label "공시 요청`n데이터 수신" 1812 1340 176 80 21
Route @(550,585,465,585,465,760,240,760,240,860) '#078577' $false $true
Label "화면의 공식 링크로`n사용자가 이동" 60 650 365 85 23 '#08786D'

Label 'AI는 조건과 설명을 제안하고, 서버는 확정 조건에 따라 검색·계산합니다.' 545 1510 1800 48 25 $script:Ink $true $false
SaveCanvas 'logical-architecture-draft.png'

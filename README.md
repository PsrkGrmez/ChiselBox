# ChiselBox

Safe way to use V2ray Banned ip Configs Using Chisel Library.
Credit : [Chisel Github](https://github.com/jpillora/chisel)

> [!WARNING]
> این پروژ درحال توسعه است و به یک ریفکتور اساسی نیاز دارد.



This project is a WS / TCP / UDP based connection throw  V2RAY and Chisel library. 



## Installing Server Side 
قبل از همه چی یدونه کانفیگ ریالیتی با تنظیمات دخواه روی پورت 443 میسازیم. 
دقیت کنید که پورت 80 هم باید آزاد باشه روی سرورمون.
برای نصب کانکشن سمت سرور کافیه کامند های زیر رو به ترتیب توی ترمینال سرورتون بزنید:

``` sh
mkdir chisel && cd chisel
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_linux_amd64.gz
gunzip chisel_1.9.1_linux_amd64.gz
chmod +x chisel_1.9.1_linux_amd64
tmux
```

حالا وارد CloudFlare میشیم یه زیر دامنه میسازیم که به آدرس ip سرورتون اشاره میکنه.<br>
حواستون باشه که حتما تیک Proxy روشن باشه.<br>
برای مثال ip سرور من 1.1.1.1 هست و دامنه من google.com , من یه سابدامین میسازم به اسم chisel حالا دامنه ای ک داریم اینه chisel.google.com. <br>
تو این مرحله برمیگردیم به ترمینا سرورمون و دستوری زیر رو میزنیم:
``` sh
./chisel_1.9.1_linux_amd64 server --port 80 --socks5 443 --proxy http://xxx.yourdomain.com -v
```

دقت کنید که توی دستور بالا حتما حتما دامنه خودتون رو با xxx.yourdomain.com عوض کنید!<br>
مثلا برای مثالی که بالاتر زدم میشه :
``` sh
./chisel_1.9.1_linux_amd64 server --port 80 --socks5 443 --proxy http://chisel.google.com -v
```

الان بدون اینکه دست به چیزی بزنید مستقیم ترمینال رو ببندید و از سرور خارج بشید چون ما از دستور tmux استفاده کردیم تا وقتی که سرور ریبوت نشه اسکریپت Chisel فعال مییمونه.<br>
تا اینجا کاری به سرور نداریم دیگه , فقط کانفیگ ریالیتی که ساخته بودیم رو کپی میکنیم میبریم یجایی ک بتونیم ادیتش کنیم.

## Using ChiselBox Client
<br><br>
> [!NOTE]
> درحال حاضر 2 سرور اهدایی به صورت رایگان در اپلیکیشین موجود هست.

تو مرحله قبلی ما سرور رو کانفیگ کردیم حالا نوبت میرسه به استفاده از برنامه.<br>
کانفیگ ریالیتی که ساختیم رو ویرایش میکنیم و به جای آدرس ip یا دامنه ای که خودش داره آدرس زیردامنه جدیدی که ساختیم رو میزنیم.<br>
برای مثالی که من بالا زدم میشه chisel.google.com به این صورت : 


![image](https://github.com/PsrkGrmez/ChiselBox/assets/160428781/196572a2-8b22-4fa0-b92b-8385797e15cd)

به چیز های دیگه دست نزنید , بعد از ویرایش کانفیگ حالا همین کانفیگ رو کپی میکنیم و وارد برنامه ChiselBox میشیم:




![image](https://github.com/PsrkGrmez/ChiselBox/assets/160428781/63dff6c0-0750-45e6-9cfc-08b73d137a94)
![image](https://github.com/PsrkGrmez/ChiselBox/assets/160428781/7bd8f587-5cba-431a-8ce9-0b037f7bc13f)



رویدکمه پایین صفحه کلیک کنید و گزینه ( + ) رو بزنید تا کانفیگ براتون توی برنامه لود بشه:


![image](https://github.com/PsrkGrmez/ChiselBox/assets/160428781/a090a5c6-c51d-4ebb-947e-d9b1568a3e2c)

حالا کافیه یکبار روی کانفیگ اضافه شده به بخش Custom Configs ضربه بزنید تا سروری که اضافه کردید براتون انتخاب بشه.<br>
الان میتونید با دکمه اتصال وی پی ان رو روشن کنید و از کانکشن آزاد به راحتی استفاده کنید.<br><br>

نکته : بعد از روشن کردن وی پی ان چندثانیه صبر کنید تا ترافیک رد بشه. <br>
نکته 2 : اگر به سروری که ساختید متصل شدید اما کار نمیکنه یکی از مراحل رو اشتباه رفتید.<br>
نکته 3 : اپلیکیشین بسیار بسیار شلخته نوشته شده, و فرصت نشد ریفکتور انجام بدم پس منتظر Pull Request هاتون هستم :+1: 

# Plantly Inventory — Politica de confidențialitate

**Data intrării în vigoare:** 7 octombrie 2026
**Operator:** URUNDEAD LABS S.R.L., România (CUI 54762154) — contact: admin@plantly.ro
*English: see [privacy-policy.en.md](privacy-policy.en.md).*

## Pe scurt

Plantly Inventory este o aplicație de îngrijire a plantelor care funcționează offline. Pe Android merge fără cont: plantele, pozele, notițele, memento-urile și istoricul de îngrijire sunt stocate **doar pe dispozitivul tău**, fără reclame și fără urmărire. Nimic nu părăsește telefonul decât dacă trimiți tu ceva în mod explicit (un backup, un link pe care îl deschizi), dacă activezi raportarea opțională a erorilor și a utilizării (**dezactivată implicit**) sau dacă pornești **Inventory Cloud**.

**Inventory Cloud** este un serviciu opțional, cu plată. Când te conectezi cu contul tău plantly.ro și ai un abonament activ, colecția ta se sincronizează cu acel cont, ca să aibă o copie de siguranță și să fie disponibilă pe celelalte dispozitive și în browser. **Versiunea web** (inventory.plantly.ro) face parte din Inventory Cloud: funcționează întotdeauna cu contul tău plantly.ro și cu colecția sincronizată.

## Ce stochează aplicația pe dispozitiv

- Plante, spații (camere), etichete, programe și istoric de îngrijire
- Pozele pe care le atașezi și notițele sau descrierile pe care le scrii
- Setările de memento-uri și notificări, orele de liniște, tema și limba
- Cele două comutatoare de confidențialitate (rapoarte de erori, utilizare anonimă)
- Dacă folosești Inventory Cloud: sesiunea de conectare plantly.ro și colecția la care este legat dispozitivul

Toate acestea se află în stocarea privată a aplicației (în versiunea web: stocarea browserului pentru acest site). Fără Inventory Cloud noi nu le putem vedea și nu prelucrăm nimic din ele pe un server. Dezinstalarea aplicației le elimină; în browser, ștergerea datelor site-ului.

## Ce părăsește dispozitivul — și când

**Fără Inventory Cloud: nimic, în mod implicit.** Situațiile de mai jos apar doar când le declanșezi tu:

- **Backup-uri și exporturi** (JSON, ZIP cu poze, CSV, iCal). Sunt create pe dispozitiv și predate aplicației pe care o alegi, prin meniul de partajare sau selectorul de fișiere al sistemului (în browser: descărcate ca fișier). Unde ajung depinde de tine.
- **Linkuri pe care le deschizi.** Unele ecrane pot deschide plantly.ro în browser, unde se aplică [politica de confidențialitate plantly.ro](https://plantly.ro/privacy).
- **Date despre plante primite prin link.** Aplicația poate primi detalii despre o plantă printr-un link `plantlyinventory://import` sau `plantly.ro/app/inventory/import`, de exemplu din Plantly Assistant sau de pe plantly.ro. Datele sunt conținute chiar în link și sunt prelucrate doar pe dispozitivul tău; nimic nu este trimis înapoi.

**Notificările** sunt programate local de sistemul de operare. Nu există un server de push. Versiunea web nu afișează notificări de sistem; memento-urile apar în aplicație și în calendar.

## Inventory Cloud (opțional)

Inventory Cloud pornește doar când te conectezi cu un cont plantly.ro (cu datele tale plantly.ro, cu Google sau cu altă metodă de conectare oferită de plantly.ro) și contul are un abonament Inventory Cloud activ (inclus și în Plantly Pro). Contul plantly.ro în sine este acoperit de [politica de confidențialitate plantly.ro](https://plantly.ro/privacy).

**Ce se sincronizează.** Cât timp sincronizarea este pornită, aplicația trimite în contul tău plantly.ro modificările pe care le faci în colecție: plante, spații, etichete, programe de îngrijire, evenimente de îngrijire, intrări de inventar, notițe și pozele atașate. Fiecare modificare poartă utilizatorul plantly.ro care a făcut-o și un identificator tehnic al dispozitivului. Pozele sunt stocate într-un spațiu de stocare **privat** (Cloudflare R2, operat pentru plantly.ro) și pot fi accesate doar prin linkuri temporare emise membrilor colecției — nu sunt niciodată publice.

**Dispozitive.** Ca să le poți vedea și deconecta din Eu → Cloud → Dispozitive, fiecare dispozitiv sincronizat transmite numele său (pe un computer, numele lui din rețea (hostname); pe telefoane, eticheta platformei, de exemplu „Android”; în browser, „Browser”), platforma, versiunea aplicației și când a fost văzut ultima dată.

**Colecții partajate.** Dacă partajezi o colecție, persoanele pe care le inviți (cu un cod sau un link de invitație creat de tine) îi pot vedea — și, dacă le dai acest rol, edita — plantele, pozele și istoricul, inclusiv ce membru a făcut fiecare modificare. Poți elimina membri sau șterge colecția oricând; membrii păstrează copia aflată deja pe dispozitivele lor.

**Abonamente.** Pe Android te poți abona prin **Google Play Billing**. Google procesează plata conform propriei politici de confidențialitate; noi nu vedem niciodată datele cardului. Google primește doar un identificator derivat ireversibil (hash) al contului tău plantly.ro, ca achiziția să fie asociată contului corect — niciodată numele sau e-mailul tău. Cât timp ești conectat, aplicația trimite către plantly.ro tokenul de achiziție și produsul, ca să confirme abonamentul. Pe plantly.ro, abonamentele sunt gestionate de plantly.ro (plăți prin Stripe), conform politicii de confidențialitate plantly.ro.

**Notificări despre colecții.** Te putem anunța în contul tău plantly.ro (clopoțelul de notificări și push, dacă folosești aplicația plantly.ro) despre colecțiile tale — de exemplu când cineva intră într-o colecție pe care o partajezi sau înainte ca datele din cloud să fie șterse după expirarea abonamentului. Despre această ștergere îți scriem și pe e-mail, dacă setările de e-mail plantly.ro o permit.

**Păstrare și ștergere.**
- Oprirea sincronizării pe un dispozitiv („Deconectează acest dispozitiv”) sau delogarea oprește sincronizarea; nu șterge nimic, nici de pe dispozitiv, nici din cont.
- **Istoricul sincronizării.** Copia din cloud a unei colecții este un istoric al modificărilor. Ștergerea unei plante sau a unei poze în aplicație o elimină de pe toate dispozitivele sincronizate, dar valorile anterioare rămân în acest istoric până când întreaga colecție este ștearsă, ca mai jos.
- **Ștergerea unei colecții.** Când proprietarul șterge o colecție, toți membrii pierd imediat accesul, iar datele ei din cloud — istoricul sincronizării și pozele — sunt șterse automat de curățenia noastră zilnică, de regulă în aproximativ 24 de ore.
- **Expirarea abonamentului.** Dacă abonamentul proprietarului expiră, sincronizarea se oprește, dar colecția mai poate fi descărcată timp de 30 de zile. După aproximativ 83 de zile fără abonament activ, proprietarul este avertizat în contul plantly.ro (și pe e-mail, dacă permite); datele colecției din cloud, inclusiv pozele, sunt șterse **nu mai devreme de 90 de zile** de la expirare și **niciodată fără acest avertisment**. Reactivarea înainte de termen anulează ștergerea. Membrii unei colecții partajate depind de abonamentul proprietarului: când acesta expiră astfel, se încheie și accesul lor la copia din cloud.
- Datele de pe dispozitivele tale nu sunt șterse niciodată prin niciunul dintre aceste procese; membrii păstrează copia aflată deja pe dispozitivele lor.
- Ca datele din cloud să fie șterse mai devreme, scrie la admin@plantly.ro.

## Rapoarte de erori și statistici de utilizare opționale

În **Eu → Confidențialitate și date** există două comutatoare, ambele **dezactivate** până le pornești tu:

- **Rapoarte de erori** — dacă aplicația se blochează, mesajul de eroare și stack trace-ul sunt trimise ca să putem repara problema.
- **Utilizare anonimă** — un nume scurt de eveniment (de exemplu ecranul sau funcția folosită) cu câteva etichete de categorie, ca să știm ce funcții contează.

Când sunt activate, rapoartele ajung la Sentry (Functional Software, Inc.), un serviciu de raportare a erorilor care acționează ca persoană împuternicită de noi, și sunt păstrate implicit 90 de zile. Fiecare raport conține și context tehnic: versiunea aplicației, modelul dispozitivului, versiunea sistemului de operare, limba, fusul orar și un identificator aleatoriu de instalare creat de biblioteca de raportare, nelegat de numele tău, de e-mail sau de vreun cont. Rapoartele **nu** conțin niciodată date despre plante, poze, text introdus de tine, contacte sau locația precisă.

Versiunea publicată pe Google Play este livrată **fără un punct de raportare configurat**, deci în prezent nu se transmite nimic chiar dacă comutatoarele sunt pornite. Dacă o actualizare viitoare activează raportarea, comutatoarele o vor controla, iar această politică va fi actualizată. Poți dezactiva oricare opțiune oricând; schimbarea are efect imediat.

## Vânzarea pe plantly.ro (neactivată în această versiune)

În cod există o funcție opțională „Vinde pe plantly.ro”, **dezactivată** în această versiune. Dacă o actualizare viitoare o activează, va necesita un cont plantly.ro și va publica pe plantly.ro doar anunțul pe care îl compui și îl verifici (titlu, descriere, preț, categorie, localitate, până la șase poze), conform politicii de confidențialitate plantly.ro — nimic altceva din colecția ta. Vom actualiza mai întâi această politică și ecranul de confidențialitate din aplicație.

## Permisiuni

- **Notificări** — pentru a afișa memento-urile de îngrijire.
- **Pornire la boot** — pentru a reprograma memento-urile după o repornire.
- **Internet** — doar pentru situațiile de mai sus (conectare și sincronizare Inventory Cloud, abonamente Google Play, rapoarte opționale, linkuri pe care le deschizi).
- Pozele sunt alese prin selectorul de fotografii al sistemului sau făcute cu aplicația ta de cameră; aplicația în sine nu cere permisiunea de cameră și nu îți scanează galeria.

## Copii

Plantly Inventory este destinată utilizatorilor cu vârsta de cel puțin 18 ani. Nu colectează cu bună știință date personale de la nimeni, inclusiv de la copii.

## Drepturile tale

Pentru datele care rămân pe dispozitivul tău, accesul, rectificarea, ștergerea și portabilitatea le exerciți singur: exportă un backup, editează sau șterge intrări ori dezinstalează aplicația. Pentru datele din Inventory Cloud, aceleași instrumente din aplicație se aplică și colecției sincronizate; în plus, poți scrie la admin@plantly.ro ca să accesezi, exporți sau ștergi copia din cloud ori să închizi contul plantly.ro. Pentru ștergerea rapoartelor opționale de erori sau utilizare scrie la admin@plantly.ro. Poți depune și o plângere la autoritatea de protecție a datelor (în România: ANSPDCP).

## Modificări ale acestei politici

Actualizările sunt publicate aici, cu o nouă dată de intrare în vigoare; modificările importante sunt menționate și în notele de lansare ale aplicației.

## Contact

URUNDEAD LABS S.R.L. — admin@plantly.ro

# Plantly Inventory — Politica de confidențialitate

**Data intrării în vigoare:** 25 septembrie 2026
**Operator:** URUNDEAD LABS S.R.L., România (CUI 54762154) — contact: admin@plantly.ro
*English: see [privacy-policy.en.md](privacy-policy.en.md).*

## Pe scurt

Plantly Inventory este o aplicație de îngrijire a plantelor care funcționează offline. Plantele, pozele, notițele, memento-urile și istoricul de îngrijire sunt stocate **doar pe dispozitivul tău**. Nu există cont, cloud, reclame sau urmărire. Nimic nu părăsește telefonul decât dacă trimiți tu ceva în mod explicit (un backup, un link pe care îl deschizi) sau dacă activezi raportarea opțională a erorilor și a utilizării, care este **dezactivată implicit**.

## Ce stochează aplicația pe dispozitiv

- Plante, spații (camere), etichete, programe și istoric de îngrijire
- Pozele pe care le atașezi și notițele sau descrierile pe care le scrii
- Setările de memento-uri și notificări, orele de liniște, tema și limba
- Cele două comutatoare de confidențialitate (rapoarte de erori, utilizare anonimă)

Toate acestea se află în stocarea privată a aplicației. Noi nu le putem vedea și nu prelucrăm nimic din ele pe un server. Dezinstalarea aplicației le elimină.

## Ce părăsește dispozitivul — și când

**Nimic, în mod implicit.** Situațiile de mai jos apar doar când le declanșezi tu:

- **Backup-uri și exporturi** (JSON, ZIP cu poze, CSV, iCal). Sunt create pe dispozitiv și predate aplicației pe care o alegi, prin meniul de partajare sau selectorul de fișiere al sistemului. Unde ajung depinde de tine.
- **Linkuri pe care le deschizi.** Unele ecrane pot deschide plantly.ro în browser, unde se aplică [politica de confidențialitate plantly.ro](https://plantly.ro/privacy).
- **Date despre plante primite prin link.** Aplicația poate primi detalii despre o plantă printr-un link `plantlyinventory://import` sau `plantly.ro/app/inventory/import`, de exemplu din Plantly Assistant sau de pe plantly.ro. Datele sunt conținute chiar în link și sunt prelucrate doar pe dispozitivul tău; nimic nu este trimis înapoi.

**Notificările** sunt programate local de sistemul de operare. Nu există un server de push.

## Rapoarte de erori și statistici de utilizare opționale

În **Eu → Confidențialitate și date** există două comutatoare, ambele **dezactivate** până le pornești tu:

- **Rapoarte de erori** — dacă aplicația se blochează, mesajul de eroare și stack trace-ul sunt trimise ca să putem repara problema.
- **Utilizare anonimă** — un nume scurt de eveniment (de exemplu ecranul sau funcția folosită) cu câteva etichete de categorie, ca să știm ce funcții contează.

Când sunt activate, rapoartele ajung la Sentry (Functional Software, Inc.), un serviciu de raportare a erorilor care acționează ca persoană împuternicită de noi, și sunt păstrate implicit 90 de zile. Fiecare raport conține și context tehnic: versiunea aplicației, modelul dispozitivului, versiunea sistemului de operare, limba, fusul orar și un identificator aleatoriu de instalare creat de biblioteca de raportare, nelegat de numele tău, de e-mail sau de vreun cont. Rapoartele **nu** conțin niciodată date despre plante, poze, text introdus de tine, contacte sau locația precisă.

Versiunea publicată pe Google Play este livrată **fără un punct de raportare configurat**, deci în prezent nu se transmite nimic chiar dacă comutatoarele sunt pornite. Dacă o actualizare viitoare activează raportarea, comutatoarele o vor controla, iar această politică va fi actualizată. Poți dezactiva oricare opțiune oricând; schimbarea are efect imediat.

## Vânzarea pe plantly.ro (neactivată în această versiune)

În cod există o funcție opțională „Vinde pe plantly.ro”, **dezactivată** în această versiune. Dacă o actualizare viitoare o activează, va necesita un cont plantly.ro și va trimite către plantly.ro doar anunțul pe care îl compui și îl verifici (titlu, descriere, preț, categorie, localitate, până la șase poze), conform politicii de confidențialitate plantly.ro — nimic altceva din colecția ta. Vom actualiza mai întâi această politică și ecranul de confidențialitate din aplicație.

## Permisiuni

- **Notificări** — pentru a afișa memento-urile de îngrijire.
- **Pornire la boot** — pentru a reprograma memento-urile după o repornire.
- **Internet** — doar pentru situațiile de mai sus (rapoarte opționale, linkuri pe care le deschizi).
- Pozele sunt alese prin selectorul de fotografii al sistemului sau făcute cu aplicația ta de cameră; aplicația în sine nu cere permisiunea de cameră și nu îți scanează galeria.

## Copii

Plantly Inventory este destinată utilizatorilor cu vârsta de cel puțin 18 ani. Nu colectează cu bună știință date personale de la nimeni, inclusiv de la copii.

## Drepturile tale

Deoarece datele rămân pe dispozitivul tău, accesul, rectificarea, ștergerea și portabilitatea le exerciți singur: exportă un backup, editează sau șterge intrări ori dezinstalează aplicația. Pentru ștergerea rapoartelor opționale de erori sau utilizare scrie la admin@plantly.ro. Poți depune și o plângere la autoritatea de protecție a datelor (în România: ANSPDCP).

## Modificări ale acestei politici

Actualizările sunt publicate aici, cu o nouă dată de intrare în vigoare; modificările importante sunt menționate și în notele de lansare ale aplicației.

## Contact

URUNDEAD LABS S.R.L. — admin@plantly.ro

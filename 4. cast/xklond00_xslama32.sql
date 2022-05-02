DROP TABLE nabidky_ke_koupi;
DROP TABLE zadosti_o_prohlidku;
DROP TABLE kupni_smlouvy;
DROP TABLE nemovitosti;
DROP TABLE zamestnanci;
DROP TABLE zakaznici;
DROP TABLE zakaznici_s_radnym_uctem;


CREATE TABLE zamestnanci
(
    zamestnanci_ID
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    jmeno
        VARCHAR(60) NOT NULL,
    datum_nastupu
        DATE NOT NULL,
    datum_vypovedi
        DATE NULL,
    pozice
        VARCHAR(60)
);

CREATE TABLE zakaznici_s_radnym_uctem
(
    zakaznici_id_s_radnym_uctem_id
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    adresa
        VARCHAR(1024) NOT NULL, -- zakaznici s radnym uctem se vyznacuje tim, ze o nem mame blizsi informace
    kategorie_zakaznicia
        VARCHAR(16) NOT NULL CHECK (kategorie_zakaznicia IN ('pravnicka osoba', 'fyzicka osoba'))
);

CREATE TABLE zakaznici
(
    zakaznici_id
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    jmeno
        VARCHAR(60) NOT NULL,
    email
        NVARCHAR2(60),
    CHECK (REGEXP_LIKE(
            email, '^[a-z]+[a-z0-9\.]*@[a-z0-9\.-]+\.[a-z]{2,}$', 'i'
        )),
    telefonni_cislo
        VARCHAR(20) NOT NULL,
    login
        VARCHAR(18) NOT NULL,
    heslo
        VARCHAR(256) NOT NULL,
    zakaznici_s_radnym_uctem_fk
        INT DEFAULT NULL,
    CONSTRAINT zakaznici_s_radnym_uctem_fk
        FOREIGN KEY (zakaznici_s_radnym_uctem_fk) REFERENCES zakaznici_s_radnym_uctem (zakaznici_id_s_radnym_uctem_id)
            ON DELETE SET NULL
);

CREATE TABLE nemovitosti
(
    nemovitosti_ID
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    typ_nemovitosti
        VARCHAR(60),
    plocha
        INT CHECK ( plocha >= 0 ),
    poloha
        VARCHAR(200),
    cena
        DECIMAL(12, 3) CHECK ( cena >= 0 ),
    blizsi_popis
        VARCHAR(2048),
    zamestnanci
        INT DEFAULT NULL,
    vlastnik
        INT DEFAULT NULL,
    zakaznici
        INT DEFAULT NULL,
    CONSTRAINT vlozil_do_systemu_fk
        FOREIGN KEY (zamestnanci) REFERENCES zamestnanci (zamestnanci_ID)
            ON DELETE SET NULL,
    CONSTRAINT vlastnik_fk
        FOREIGN KEY (vlastnik) REFERENCES zakaznici_s_radnym_uctem (zakaznici_id_s_radnym_uctem_id)
            ON DELETE SET NULL
);

CREATE TABLE kupni_smlouvy
(
    smlouva_ID
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    datum_uzavreni_smlouvy
        DATE DEFAULT NULL,
    stav
        VARCHAR(20) DEFAULT 'neuzavrena' CHECK ( stav IN ('uzavrena', 'neuzavrena')),
    obsah_smlouvy
        VARCHAR(4000) NOT NULL,
    zakaznici
        INT DEFAULT NULL,
    zamestnanci
        INT DEFAULT NULL,
    nemovitosti
        INT DEFAULT NULL,
    CONSTRAINT figurujici_zakaznici_fk
        FOREIGN KEY (zakaznici) REFERENCES zakaznici_s_radnym_uctem (zakaznici_id_s_radnym_uctem_id)
            ON DELETE SET NULL,
    CONSTRAINT zadal_zamestnanci_fk
        FOREIGN KEY (zamestnanci) REFERENCES zamestnanci (zamestnanci_ID)
            ON DELETE SET NULL,
    CONSTRAINT figurujici_nemovitosti_fk
        FOREIGN KEY (nemovitosti) REFERENCES nemovitosti (nemovitosti_ID)
            ON DELETE SET NULL
);

CREATE TABLE zadosti_o_prohlidku
(
    zadost_ID
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    pozadovany_datum_a_cas_prohlidky
        DATE NOT NULL,
    datum_podani_zadosti
        TIMESTAMP,
    probehla
        VARCHAR(3) DEFAULT 'ne' CHECK (probehla IN ('ano', 'ne')),
    nemovitosti
        INT DEFAULT NULL,
    zakaznici
        INT DEFAULT NULL,
    CONSTRAINT prohlidka_nemovitostii_fk
        FOREIGN KEY (nemovitosti) REFERENCES nemovitosti (nemovitosti_ID)
            ON DELETE SET NULL,
    CONSTRAINT zadajici_zakaznici_fk
        FOREIGN KEY (zakaznici) REFERENCES zakaznici (zakaznici_id)
            ON DELETE SET NULL
);

CREATE TABLE nabidky_ke_koupi
(
    nabidka_ID
        INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    vyse_nabidky
        DECIMAL(12, 3) NOT NULL CHECK ( vyse_nabidky >= 0 ),
    datum_podani_nabidky
        TIMESTAMP,
    nemovitosti
        INT DEFAULT NULL,
    zakaznici
        INT DEFAULT NULL,
    CONSTRAINT zadana_nemovitosti_fk
        FOREIGN KEY (nemovitosti) REFERENCES nemovitosti (nemovitosti_ID)
            ON DELETE SET NULL,
    CONSTRAINT nabizejici_zakaznici_fk
        FOREIGN KEY (zakaznici) REFERENCES zakaznici (zakaznici_id)
            ON DELETE SET NULL
);
-- TRIGGER --------------------------------------------------------------------------------------------

-- trigger na hash hesla
-- trigger na predelani casu prohlidky pokud uz je zabrany

-- pokud insertujeme heslo kratsi nez 12 znaku prida k nemu sugar a zahashuje, pokud je delsi tak pouze zahashuje
CREATE OR REPLACE TRIGGER make_password_safe
        BEFORE INSERT OR UPDATE ON zakaznici
        FOR EACH ROW
DECLARE
         sugar VARCHAR(256);
BEGIN
        IF LENGTH(:NEW.heslo) < 12 THEN
            sugar := :NEW.login || :NEW.telefonni_cislo || 'fSs687fDcF';

            :NEW.heslo := DBMS_OBFUSCATION_TOOLKIT.MD5(
            input => UTL_I18N.STRING_TO_RAW(:NEW.heslo || sugar)
            );

        ELSE
            :NEW.heslo := DBMS_OBFUSCATION_TOOLKIT.MD5(
			input => UTL_I18N.STRING_TO_RAW(:NEW.heslo)
		    );
        END IF;
END;
/

-- zmena stavu smlouvy podle datumu uzavreni, pokud po, tak uzavrena, pokud pred, tak neuzavrena a pokud neurceny datum tak neuzavrena
CREATE OR REPLACE TRIGGER zmena_stavu
    BEFORE INSERT OR UPDATE ON kupni_smlouvy
    FOR EACH ROW
    BEGIN
        IF(:NEW.datum_uzavreni_smlouvy < CURRENT_DATE) THEN
            :NEW.stav := 'uzavrena';
        ELSE
            :NEW.stav := 'neuzavrena';
        END IF;
        IF(:NEW.datum_uzavreni_smlouvy = NULL) THEN
            :NEW.stav := 'neuzavrena';
        END IF;
    END;
/

-- INSERT ------------------------------------------------------------------------------------

INSERT INTO zamestnanci
VALUES (default, 'Josef Novák', TO_DATE('2022-04-20', 'yyyy/mm/dd'), '2.2.2020', 'generalni reditel');
INSERT INTO zamestnanci
VALUES (default, 'Erik Malina', '2-1-2019', '5.12.2021', 'delnik');
INSERT INTO zamestnanci
VALUES (default, 'Dominik Krátký', '6-1-2019', '7.2.2020', 'uklizec');
INSERT INTO zamestnanci
VALUES (default, 'Ondřej Ztracený', '23-9-2018', NULL, 'delnik');

INSERT INTO zakaznici_s_radnym_uctem
VALUES (DEFAULT, 'Brno Pisárky 10', 'fyzicka osoba');
INSERT INTO zakaznici_s_radnym_uctem
VALUES (DEFAULT, 'Praha 7', 'fyzicka osoba');

INSERT INTO zakaznici
VALUES (DEFAULT, 'Emil Houba', 'emil@houba.cz', '608233610', 'xEmil00',
        'cauky mnauky zdarec sranec', NULL);
INSERT INTO zakaznici
VALUES (DEFAULT, 'Jana černochová', 'jana.cernochova@mo.cz', '+420 225 200 400', 'xJanaObrana00',
        'sem debilek', NULL);
INSERT INTO zakaznici
VALUES (DEFAULT, 'Karolína Pepsi', 'kajicka@kocicka.cz', '+420 2544 655 887', 'xKaja44',
        'kkt nooooooooooooooooooooooooooo', 2);
INSERT INTO zakaznici
VALUES (DEFAULT, 'Antonín Klon', 'tondaklon@info.cz', '728606385', 'xAnton13',
        'ahoj', 1);

INSERT INTO nemovitosti
VALUES (default, 'chata', 84, 'praha 8', 25000000.99, 'je to v centru prahy', 1, 1, 1);
INSERT INTO nemovitosti
VALUES (default, 'dum', 152, 'brno', 250000.99, 'je to na kralove poli.', 2, 2, 1);
INSERT INTO nemovitosti
VALUES (default, 'byt', 42, 'uhersky brod', 2500.98, 'je to v centru brodu', 1, 2, 3);

INSERT INTO kupni_smlouvy
VALUES (DEFAULT, '28.4.2022', 'uzavrena', 'Koupite nemovitosti c.3 za 250000kc', 2, 2, 3);
INSERT INTO kupni_smlouvy
VALUES (DEFAULT, '26.4.2022', 'neuzavrena', 'Koupite nemovitosti c.2 za 11111kc', 2, 1, 1);
INSERT INTO kupni_smlouvy
VALUES (DEFAULT, NULL, 'uzavrena', 'Koupite nemovitosti c.2 za 11111kc', 2, 1, 1);

INSERT INTO zadosti_o_prohlidku
VALUES (DEFAULT, '2.5.2022', CURRENT_TIMESTAMP, 'ne', 2, 2);
INSERT INTO zadosti_o_prohlidku
VALUES (DEFAULT, '2.7.2020', CURRENT_TIMESTAMP, 'ano', 1, 3);

INSERT INTO nabidky_ke_koupi
VALUES (DEFAULT, 5000000, CURRENT_TIMESTAMP, 1, 3);
INSERT INTO nabidky_ke_koupi
VALUES (DEFAULT, 125000, CURRENT_TIMESTAMP, 1, 1);


-- PROCEDURES --------------------------------------------------------------------------------

-- procedure vypise statistiku nabidek k vybrane nemovitosti
-- nejvyssi, nejnizsi nabidku, prumer nabidek a pocet nabidek
CREATE OR REPLACE PROCEDURE show_offers_stats
    (selected_id_nemovitosti IN INT)
AS
    max_offer NUMBER;
    min_offer NUMBER;
    avg_offer NUMBER;
    count_offer NUMBER;
    number_of_properties NUMBER;
BEGIN
    SELECT COUNT(nemovitosti_ID) INTO number_of_properties FROM nemovitosti WHERE nemovitosti_ID = selected_id_nemovitosti;

    IF (number_of_properties = 0) THEN
        DBMS_OUTPUT.put_line(
		'Neexistující nemovitost s daným ID.'
	);
        RETURN ;
    END IF;

    -- MAXIMUM OFFER ----------
    SELECT max(vyse_nabidky) INTO max_offer FROM nabidky_ke_koupi zad JOIN zakaznici zak ON zad.zakaznici = zak.zakaznici_id
    JOIN nemovitosti nem ON zad.nemovitosti = nem.nemovitosti_ID;

    IF (max_offer IS NULL) THEN -- checking once is enough due to all the statistics are done at once
        DBMS_OUTPUT.put_line(
		'Na danou nemovitost neexistují žádné nabídky.'
	);
        RETURN ;
    END IF;

    DBMS_OUTPUT.put_line(
		'Maximalni nabidka: ' || max_offer
	);

    -- MINIMUM OFFER
    SELECT min(vyse_nabidky) INTO min_offer FROM nabidky_ke_koupi zad JOIN zakaznici zak ON zad.zakaznici = zak.zakaznici_id
    JOIN nemovitosti nem ON zad.nemovitosti = nem.nemovitosti_ID;

    DBMS_OUTPUT.put_line(
		'Minimalni nabidka: ' || min_offer
	);

    -- AVARAGE OFFER
    SELECT avg(vyse_nabidky) INTO avg_offer FROM nabidky_ke_koupi zad JOIN zakaznici zak ON zad.zakaznici = zak.zakaznici_id
    JOIN nemovitosti nem ON zad.nemovitosti = nem.nemovitosti_ID;

    DBMS_OUTPUT.put_line(
		'Prumerna nabidka: ' || avg_offer
	);

    -- COUNT OFFER
    SELECT count(*) INTO count_offer FROM nabidky_ke_koupi zad JOIN zakaznici zak ON zad.zakaznici = zak.zakaznici_id
    JOIN nemovitosti nem ON zad.nemovitosti = nem.nemovitosti_ID;

    DBMS_OUTPUT.put_line(
		'Pocet nabidek: ' || count_offer
	);
END;
/

-- Chceme ukazat statistiky nabidek k nemovisti cislo jedna
BEGIN show_offers_stats(1); END;
-- Nemovitost cislo 5 neexistuje, proto vyhodi chybu
BEGIN show_offers_stats(5); END;


-- Procedura zmeni jmeno a heslo vybraneho zakaznika
CREATE OR REPLACE PROCEDURE change_login
    (
    selected_customer_id IN NUMBER,
    new_login IN zakaznici.login%TYPE,
    new_password IN zakaznici.heslo%TYPE
    )
    AS
    CURSOR cursor_zakaznici IS SELECT zakaznici.zakaznici_id from zakaznici;
    customer_id zakaznici.zakaznici_id%TYPE;
BEGIN
    OPEN cursor_zakaznici;
    LOOP
        FETCH cursor_zakaznici INTO customer_id;
        EXIT WHEN cursor_zakaznici%NOTFOUND;
        IF (customer_id = selected_customer_id) THEN
            UPDATE XKLOND00.zakaznici SET
                                login = new_login,
                                heslo = new_password WHERE ZAKAZNICI_ID = customer_id; -- trigger "make_password_safe" automaticky zmeni heslo na hash
        END IF;

    END LOOP;
    CLOSE cursor_zakaznici;
END;

-- predvedeni funkcionality procedury "change_login"
-- pred zmenou
SELECT * FROM zakaznici;
BEGIN change_login(4, 'xklond00','supertajneheslo' ); END;
-- po zmene
SELECT * FROM zakaznici;

-- PRIVILEGES -----------------------------------------------------------------------------------

GRANT ALL on zakaznici_s_radnym_uctem TO XSLAMA32;
GRANT ALL ON nemovitosti TO XSLAMA32;
GRANT ALL  ON kupni_smlouvy TO XSLAMA32;
GRANT ALL ON zamestnanci TO XSLAMA32;
GRANT ALL ON zakaznici TO XSLAMA32;
GRANT ALL ON zadosti_o_prohlidku TO XSLAMA32;
GRANT ALL ON nabidky_ke_koupi TO XSLAMA32;
GRANT ALL ON pohled TO XSLAMA32;
GRANT EXECUTE ON change_login TO XSLAMA32;
GRANT  EXECUTE ON show_offers_stats TO XSLAMA32;



DROP INDEX nemov_podle_vlastnika;
DROP INDEX zak_podle_rad_uctu;

-- EXPLAIN PLAN ---------------------------------------------------------------------------------------------------

-- Jaký majetek v nemovitostech má daný zákazník? Chceme ID a jmeno zakaznika a sumu jeho majetku.
EXPLAIN PLAN FOR
SELECT zakaznici_id, jmeno, SUM(cena) majetek FROM nemovitosti nem
    JOIN zakaznici_s_radnym_uctem zakr ON nem.vlastnik = zakr.zakaznici_id_s_radnym_uctem_id
    JOIN zakaznici zak ON zakr.zakaznici_id_s_radnym_uctem_id = zak.zakaznici_s_radnym_uctem_fk
    GROUP BY zakaznici_id, jmeno;

-- explain plain pred optimalizaci
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- pouziti indexu pro optimalizovani tech tabulek, ve kterych dochazi k table access full
CREATE INDEX nemov_podle_vlastnika ON nemovitosti(vlastnik);
CREATE INDEX zak_podle_rad_uctu ON zakaznici(zakaznici_s_radnym_uctem_fk);

EXPLAIN PLAN FOR
SELECT zakaznici_id, jmeno, SUM(cena) majetek FROM nemovitosti nem
    JOIN zakaznici_s_radnym_uctem zakr ON nem.vlastnik = zakr.zakaznici_id_s_radnym_uctem_id
    JOIN zakaznici zak ON zakr.zakaznici_id_s_radnym_uctem_id = zak.zakaznici_s_radnym_uctem_fk
    GROUP BY zakaznici_id, jmeno;

--explain plan po optimalizaci
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- MATERIALIZED VIEW ------------------------------------------------------------------------------------


DROP MATERIALIZED VIEW pohled;

-- Jaké žádosti o prohlídku podali daní zákazníci? Chceme ID a jmeno zakaznika, ID a polohu zadane nemovitosti, pozadovany cas
-- prohlidky a zda prohlidka probehla.
CREATE MATERIALIZED VIEW pohled
    BUILD IMMEDIATE REFRESH COMPLETE AS
    SELECT zakaznici_id, jmeno, nemovitosti_ID, poloha, pozadovany_datum_a_cas_prohlidky, probehla FROM XKLOND00.zadosti_o_prohlidku zad
    JOIN XKLOND00.zakaznici zak ON zad.zakaznici = zak.zakaznici_id
    JOIN XKLOND00.nemovitosti nem ON zad.nemovitosti = nem.nemovitosti_ID
    ORDER BY zakaznici_id ASC;

-- vypis z materialized view
SELECT * FROM pohled;

-- updatujeme hodnoty v tabulce kterou pouziva materialized view
UPDATE zakaznici SET zakaznici_id = 2 WHERE zakaznici_id = 1;

-- hodnoty v materialized view se nezmenili, jelikoz data v materialized view se po jeho provedeni ulozi do separatni tabulky
SELECT * FROM pohled;
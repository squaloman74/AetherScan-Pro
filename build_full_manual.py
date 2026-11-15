# -*- coding: utf-8 -*-
"""
AETHERSCAN-PRO v2.0 (v27-beta2) - GENERATORE MANUALE OPERATIVO FORENSE PDF DEFINITIVO
Guida Ufficiale Completa Passo-Passo per Utenti Principianti ed Esperti.
"""

import os
import sys
from PIL import Image as PILImage
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """
    Canvas a due passaggi che calcola dinamicamente il numero totale di pagine
    e disegna intestazioni e piè di pagina eleganti su ogni pagina tranne la copertina.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        if self._pageNumber == 1:
            # Pagina 1: Copertina, nessun header o footer
            return

        self.saveState()
        width, height = A4
        margin_x = 42

        # Intestazione superiore (Header)
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#00838F"))
        self.drawString(margin_x, height - 28, "AETHERSCAN-PRO v2.0 (v27-beta2)")
        
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#546E7A"))
        self.drawString(margin_x + 155, height - 28, "|   MANUALE OPERATIVO & GUIDA FORENSE SUI SENSORI")
        self.drawRightString(width - margin_x, height - 28, "STANDARD METROLOGICO RFC 4180")

        # Linea separatrice superiore
        self.setStrokeColor(colors.HexColor("#CFD8DC"))
        self.setLineWidth(0.6)
        self.line(margin_x, height - 33, width - margin_x, height - 33)

        # Piè di pagina inferiore (Footer)
        self.line(margin_x, 38, width - margin_x, 38)
        
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#78909C"))
        self.drawString(margin_x, 26, "AetherScan-Pro v2.0 • Progetto Open Metrology • Catena Crittografica SHA-256")
        
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#00838F"))
        self.drawRightString(width - margin_x, 26, f"Pagina {self._pageNumber} di {page_count}")
        
        self.restoreState()

def build_pdf_manual():
    output_pdf = r"D:\AetherScan-Pro\DISTRIBUZIONE-FINALE\MANUALE_OPERATIVO_AETHERSCAN_PRO_v27.pdf"
    os.makedirs(os.path.dirname(output_pdf), exist_ok=True)
    
    margin = 42
    printable_width = 595.27 - (margin * 2) # ~511 pt
    
    doc = SimpleDocTemplate(
        output_pdf,
        pagesize=A4,
        leftMargin=margin,
        rightMargin=margin,
        topMargin=margin,
        bottomMargin=margin
    )
    
    # Colori Palette Industriale & Forense
    c_navy_dark    = colors.HexColor("#0A192F")
    c_cyan_dark    = colors.HexColor("#00838F")
    c_cyan_light   = colors.HexColor("#E0F7FA")
    c_amber        = colors.HexColor("#E65100")
    c_amber_light  = colors.HexColor("#FFF3E0")
    c_green        = colors.HexColor("#2E7D32")
    c_green_light  = colors.HexColor("#E8F5E9")
    c_red          = colors.HexColor("#C62828")
    c_red_light    = colors.HexColor("#FFEBEE")
    c_blue_baby    = colors.HexColor("#1565C0")
    c_blue_light   = colors.HexColor("#E3F2FD")
    c_text_dark    = colors.HexColor("#1A242F")
    c_text_muted   = colors.HexColor("#546E7A")
    c_bg_subtle    = colors.HexColor("#F8FAFC")
    c_border       = colors.HexColor("#CFD8DC")
    
    styles = getSampleStyleSheet()
    
    style_cover_title = ParagraphStyle(
        'CoverTitle', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=26, leading=32,
        textColor=c_navy_dark, alignment=1, spaceAfter=8
    )
    style_cover_sub = ParagraphStyle(
        'CoverSubtitle', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=12, leading=16,
        textColor=c_cyan_dark, alignment=1, spaceAfter=10
    )
    style_cover_desc = ParagraphStyle(
        'CoverDesc', parent=styles['Normal'],
        fontName='Helvetica', fontSize=9.5, leading=14,
        textColor=c_text_muted, alignment=1, spaceAfter=18
    )
    style_h1 = ParagraphStyle(
        'ChapterH1', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=15, leading=20,
        textColor=c_navy_dark, spaceBefore=14, spaceAfter=8, keepWithNext=True
    )
    style_h2 = ParagraphStyle(
        'SectionH2', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=11.5, leading=15,
        textColor=c_cyan_dark, spaceBefore=10, spaceAfter=5, keepWithNext=True
    )
    style_h3 = ParagraphStyle(
        'SubSectionH3', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=10, leading=13.5,
        textColor=c_text_dark, spaceBefore=8, spaceAfter=3, keepWithNext=True
    )
    style_body = ParagraphStyle(
        'BodyDark', parent=styles['Normal'],
        fontName='Helvetica', fontSize=9.0, leading=13.2,
        textColor=c_text_dark, spaceAfter=6
    )
    style_body_bold = ParagraphStyle(
        'BodyDarkBold', parent=style_body, fontName='Helvetica-Bold'
    )
    style_quote = ParagraphStyle(
        'AnalogyQuote', parent=styles['Normal'],
        fontName='Helvetica-Oblique', fontSize=9.0, leading=13.5,
        textColor=colors.HexColor("#006064"), leftIndent=10, rightIndent=10, spaceAfter=5
    )
    style_bullet = ParagraphStyle(
        'BulletText', parent=style_body,
        leftIndent=14, bulletIndent=4, spaceAfter=3
    )
    style_table_header = ParagraphStyle(
        'TableHeader', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=8.5, leading=11,
        textColor=colors.white, alignment=1
    )
    style_table_cell = ParagraphStyle(
        'TableCell', parent=styles['Normal'],
        fontName='Helvetica', fontSize=8.2, leading=11.5,
        textColor=c_text_dark
    )
    style_table_cell_bold = ParagraphStyle(
        'TableCellBold', parent=style_table_cell, fontName='Helvetica-Bold'
    )
    style_code = ParagraphStyle(
        'CodeStyle', parent=styles['Normal'],
        fontName='Courier', fontSize=7.8, leading=10,
        textColor=colors.HexColor("#004D40")
    )

    def callout(title, text, kind="info"):
        color_map = {
            "info": (c_cyan_dark, c_cyan_light, "INFORMAZIONE METROLOGICA:"),
            "amber": (c_amber, c_amber_light, "ATTENZIONE OPERATIVA:"),
            "green": (c_green, c_green_light, "REGOLA D'ORO DEL METODO:"),
            "red": (c_red, c_red_light, "ALLARME FALSI POSITIVI:"),
            "baby": (c_blue_baby, c_blue_light, "SPIEGATO IN MODO SEMPLICISSIMO (PER PRINCIPIANTI):")
        }
        b_color, bg_color, def_title = color_map.get(kind, color_map["info"])
        display_title = title if title else def_title
        
        content = [
            Paragraph(f"<b>{display_title}</b>", ParagraphStyle('CallTitle', fontName='Helvetica-Bold', fontSize=8.8, leading=11.5, textColor=b_color)),
            Spacer(1, 3),
            Paragraph(text, ParagraphStyle('CallText', fontName='Helvetica', fontSize=8.5, leading=12.5, textColor=c_text_dark))
        ]
        
        t = Table([[content]], colWidths=[printable_width])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), bg_color),
            ('BOX', (0,0), (-1,-1), 1, b_color),
            ('LEFTPADDING', (0,0), (-1,-1), 10),
            ('RIGHTPADDING', (0,0), (-1,-1), 10),
            ('TOPPADDING', (0,0), (-1,-1), 6),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ]))
        return t

    def chapter_header(title, chapter_num):
        elements = [
            PageBreak(),
            Spacer(1, 4),
            Table([
                [
                    Paragraph(f"CAPITOLO {chapter_num}", ParagraphStyle('ChBadge', fontName='Helvetica-Bold', fontSize=8.5, leading=10, textColor=colors.white, alignment=1)),
                    Paragraph(title.upper(), ParagraphStyle('ChTitle', fontName='Helvetica-Bold', fontSize=13.5, leading=17, textColor=c_navy_dark))
                ]
            ], colWidths=[75, printable_width - 85]),
            Spacer(1, 2),
            HRFlowable(width="100%", thickness=1.5, color=c_cyan_dark, spaceBefore=3, spaceAfter=10)
        ]
        t = elements[2]
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (0,0), c_cyan_dark),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('TOPPADDING', (0,0), (0,0), 4),
            ('BOTTOMPADDING', (0,0), (0,0), 4),
            ('LEFTPADDING', (1,0), (1,0), 8),
            ('BOTTOMPADDING', (1,0), (1,0), 2),
        ]))
        return elements

    def figure_card(img_path, title, bullet_points, max_w=160, max_h=230):
        if not os.path.exists(img_path):
            return Paragraph(f"<i>[Immagine {title} non reperibile su disco]</i>", style_body)
        
        with PILImage.open(img_path) as im:
            w, h = im.size
            aspect = h / w

        actual_w = max_w
        actual_h = max_w * aspect
        if actual_h > max_h:
            actual_h = max_h
            actual_w = actual_h / aspect

        img_elem = Image(img_path, width=actual_w, height=actual_h)
        
        desc_content = [
            Paragraph(f"<b>{title.upper()}</b>", ParagraphStyle('FigTitle', fontName='Helvetica-Bold', fontSize=9.5, leading=13, textColor=c_cyan_dark)),
            Spacer(1, 4),
            HRFlowable(width="100%", thickness=0.8, color=c_border, spaceBefore=0, spaceAfter=6)
        ]
        for p in bullet_points:
            desc_content.append(Paragraph(f"• {p}", ParagraphStyle('FigBullet', parent=style_body, fontSize=8.2, leading=11.5, leftIndent=8, spaceAfter=3)))
            
        t = Table([[img_elem, desc_content]], colWidths=[actual_w + 10, printable_width - actual_w - 18])
        t.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('BACKGROUND', (0,0), (-1,-1), c_bg_subtle),
            ('BOX', (0,0), (-1,-1), 1, c_border),
            ('TOPPADDING', (0,0), (-1,-1), 6),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
            ('LEFTPADDING', (0,0), (-1,-1), 6),
            ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ]))
        return KeepTogether([t, Spacer(1, 8)])

    # Screenshots paths
    p_icon = r"D:\AetherScan-Pro\AetherScan-Pro ico e imag\icon.png"
    p_calib = r"C:\Users\massi\.gemini\antigravity\brain\6f0aeb5c-4e44-4fe9-9f20-237ea4d008a2\.user_uploaded\media_1794756080655_d22eeba9.jpg"
    p_metrology = r"C:\Users\massi\.gemini\antigravity\brain\6f0aeb5c-4e44-4fe9-9f20-237ea4d008a2\.user_uploaded\media_1794756535349_c321b293.jpg"
    p_drawer = r"C:\Users\massi\.gemini\antigravity\brain\6f0aeb5c-4e44-4fe9-9f20-237ea4d008a2\.user_uploaded\media_1794756547749_b20f650d.jpg"
    p_sweep_fm = r"C:\Users\massi\.gemini\antigravity\brain\6f0aeb5c-4e44-4fe9-9f20-237ea4d008a2\.user_uploaded\media_1794756559815_19aa1c3a.jpg"
    p_hash = r"C:\Users\massi\.gemini\antigravity\brain\6f0aeb5c-4e44-4fe9-9f20-237ea4d008a2\.user_uploaded\media_1794756958252_d5998b84.jpg"
    p_sweep_am = r"C:\Users\massi\.gemini\antigravity\brain\6f0aeb5c-4e44-4fe9-9f20-237ea4d008a2\.user_uploaded\media_1794757124767_9d2daff9.jpg"

    story = []

    # =========================================================================
    # PAGINA 1: COPERTINA E CERTIFICAZIONE FORENSE
    # =========================================================================
    story.append(Spacer(1, 10))
    if os.path.exists(p_icon):
        story.append(Image(p_icon, width=75, height=75))
        story.append(Spacer(1, 12))
        
    story.append(Paragraph("AETHERSCAN-PRO v2.0", style_cover_title))
    story.append(Paragraph("MANUALE OPERATIVO FORENSE E GUIDA COMPLETA AI PARAMETRI", style_cover_sub))
    story.append(Paragraph("Edizione Ufficiale v27-beta2 • Suite Metrologica per Smartphone • Standard RFC 4180 & Crittografia SHA-256", style_cover_desc))
    story.append(HRFlowable(width="90%", thickness=1.5, color=c_cyan_dark, spaceBefore=0, spaceAfter=14))
    
    welcome_text = """
    <b>BENVENUTO NEL MONDO DELLA METROLOGIA FORENSE AMBIENTALE.</b><br/><br/>
    Questo manuale è stato redatto per rispondere a un'esigenza fondamentale: spiegare ogni singolo millimetro 
    di <b>AetherScan-Pro</b> in modo così semplice, chiaro e cristallino che <i>anche chi non ha mai visto uno strumento 
    di misura scientifico in vita sua possa padroneggiarlo al 100%</i> in pochi minuti.<br/><br/>
    Non troverai formule matematiche incomprensibili buttate lì senza spiegazione: ogni valore a schermo è accompagnato 
    dall'esempio della vita di tutti i giorni (la pressione dell'aria come l'altitudine in montagna, il campo magnetico come 
    la calamita del frigo, il filtro anti-ronzio come un setaccio per la farina).<br/><br/>
    <b>LA REGOLA FONDAMENTALE DI QUESTO PROGETTO:</b><br/>
    AetherScan-Pro non è un giocattolo. Non usa dizionari di parole pre-impostate, non simula voci paranormali con generatori 
    di numeri casuali e non racconta bugie. Se un valore si muove, significa che un sensore fisico reale nel tuo smartphone ha 
    catturato una variazione fisica autentica nell'ambiente in cui ti trovi.
    """
    story.append(callout("DICHIARAZIONE DI RIGORE SCIENTIFICO E TRASPARENZA", welcome_text, kind="green"))
    story.append(Spacer(1, 14))

    meta_table_data = [
        [Paragraph("<b>PARAMETRO</b>", style_table_header), Paragraph("<b>VALORE UFFICIALE DI RILASCIO</b>", style_table_header)],
        [Paragraph("<b>Versione Software:</b>", style_table_cell_bold), Paragraph("v2.0 (Build v27-beta2 • Release Ufficiale)", style_table_cell)],
        [Paragraph("<b>Piattaforme Supportate:</b>", style_table_cell_bold), Paragraph("Android (APK Release) & Apple iOS (IPA)", style_table_cell)],
        [Paragraph("<b>Algoritmo di Baseline:</b>", style_table_cell_bold), Paragraph("Welford M2 a passaggio singolo (30 secondi)", style_table_cell)],
        [Paragraph("<b>Soglia Anomalia Statistica:</b>", style_table_cell_bold), Paragraph("Z-Score severo ≥ 3.5σ (Confidenza statistica forense > 99.95%)", style_table_cell)],
        [Paragraph("<b>Logica Allarme Audio:</b>", style_table_cell_bold), Paragraph("Doppio Trigger Concomitante Obbligatorio (Urto Meccanico + Anomalia EMF)", style_table_cell)],
        [Paragraph("<b>Certificazione Log:</b>", style_table_cell_bold), Paragraph("RFC 4180 CSV + Digest Crittografico SHA-256 a 64 caratteri", style_table_cell)],
        [Paragraph("<b>Modalità Operative:</b>", style_table_cell_bold), Paragraph("1. Metrology Pro (Scientifica) | 2. AM/FM Spectral Sweep (Radio Live)", style_table_cell)],
    ]
    meta_t = Table(meta_table_data, colWidths=[150, printable_width - 150])
    meta_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(meta_t)
    story.append(Spacer(1, 15))
    story.append(Paragraph("<i>Custodisci questo manuale: è la tua chiave per dimostrare la totale trasparenza e inattaccabilità delle tue misurazioni sul campo.</i>", style_cover_desc))

    # =========================================================================
    # PAGINA 2: SOMMARIO COMPLETO DEI CONTENUTI
    # =========================================================================
    story.append(PageBreak())
    story.append(Paragraph("INDICE GENERALE DEL MANUALE", style_h1))
    story.append(Paragraph("Una mappa ragionata per trovare subito ciò che ti serve:", style_body))
    story.append(Spacer(1, 6))

    toc_data = [
        [Paragraph("<b>Capitolo 1</b>", style_table_cell_bold), Paragraph("<b>La Filosofia di AetherScan-Pro: Perché è diversa da tutto il resto</b><br/>La verità contro le app truccate; la metafora dell'orchestra; come farsi prendere sul serio.", style_table_cell)],
        [Paragraph("<b>Capitolo 2</b>", style_table_cell_bold), Paragraph("<b>I 4 Sensori del Telefono: Come funzionano e cosa misurano realmente</b><br/>Magnetometro (EMF), Accelerometro (Urti), Barometro (Pressione), Microfono DSP (Audio).", style_table_cell)],
        [Paragraph("<b>Capitolo 3</b>", style_table_cell_bold), Paragraph("<b>Schermata 1: Metrology Pro – Come leggere ogni singolo valore</b><br/>La barra in alto, i 4 riquadri telemetrici, l'oscilloscopio, l'FFT e i tasti di esportazione CSV/JSON.", style_table_cell)],
        [Paragraph("<b>Capitolo 4</b>", style_table_cell_bold), Paragraph("<b>La Calibrazione di 30 Secondi e l'Algoritmo di Welford</b><br/>Perché non parte più all'avvio; come funziona la fotografia statistica della stanza.", style_table_cell)],
        [Paragraph("<b>Capitolo 5</b>", style_table_cell_bold), Paragraph("<b>Il Doppio Trigger Fisico e l'Allarme Sonoro: Zero Falsi Positivi</b><br/>La verità sull'audio; la regola ferrea del 'Due in Uno'; tabella dei 4 scenari pratici.", style_table_cell)],
        [Paragraph("<b>Capitolo 6</b>", style_table_cell_bold), Paragraph("<b>Il Drawer di Navigazione: Passare tra le Modalità</b><br/>Come funziona il cassetto laterale a comparsa per scegliere tra Metrology Pro e Spectral Sweep.", style_table_cell)],
        [Paragraph("<b>Capitolo 7</b>", style_table_cell_bold), Paragraph("<b>Schermata 2: AM/FM Spectral Sweep – La Scansione Radio per le Live</b><br/>Il display centrale, la scala analogica, l'S-Meter, i controlli di velocità e i nuovi tasti REV e FWD.", style_table_cell)],
        [Paragraph("<b>Capitolo 8</b>", style_table_cell_bold), Paragraph("<b>La Catena Forense, il Codice HASH SHA-256 e i File di Log</b><br/>Cos'è l'impronta digitale di una sessione; come aprire il CSV in Excel e leggere ogni colonna.", style_table_cell)],
        [Paragraph("<b>Capitolo 9</b>", style_table_cell_bold), Paragraph("<b>Guida ad Excel e Creazione dei Grafici Forensi</b><br/>Come ordinare i dati, evidenziare gli eventi anomali e generare grafici da mostrare al pubblico.", style_table_cell)],
        [Paragraph("<b>Capitolo 10</b>", style_table_cell_bold), Paragraph("<b>Vademecum Pratico sul Campo: Guida per l'Operatore Serio</b><br/>Checklist prima di partire, i 10 errori più comuni del principiante e come condurre una Live.", style_table_cell)],
        [Paragraph("<b>Capitolo 11</b>", style_table_cell_bold), Paragraph("<b>20 Casi Studio Reali Risolti sul Campo</b><br/>Cosa è successo realmente sul display e come interpretare ogni singola combinazione di valori.", style_table_cell)],
        [Paragraph("<b>Capitolo 12</b>", style_table_cell_bold), Paragraph("<b>Domande Frequenti (FAQ) e Risoluzione dei Dubbi</b><br/>Perché il valore non è mai zero? Perché a volte l'allarme non suona? Come mostrare le prove.", style_table_cell)],
        [Paragraph("<b>Capitolo 13</b>", style_table_cell_bold), Paragraph("<b>Glossario Scientifico Illustrato dalla A alla Z</b><br/>Spiegazione facilissima di tutti i termini: microTesla, Z-Score, Welford, S-Meter, dBFS, Notch.", style_table_cell)],
        [Paragraph("<b>Capitolo 14</b>", style_table_cell_bold), Paragraph("<b>Scheda di Rilascio v27-beta2 e Checksum Ufficiali</b><br/>Impronte crittografiche SHA-256 dei binari di compilazione.", style_table_cell)],
    ]
    toc_t = Table(toc_data, colWidths=[85, printable_width - 85])
    toc_t.setStyle(TableStyle([
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 4.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4.5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(toc_t)
    story.append(Spacer(1, 10))
    story.append(callout("CONSIGLIO DI LETTURA RAPIDA", 
        "Se è la prima volta che apri l'applicazione, ti consigliamo di leggere con attenzione i <b>Capitoli 1, 2 e 3</b>. "
        "Se sei già sul campo e vuoi solo capire cosa significa un numero strano che vedi lampeggiare, consulta direttamente "
        "il <b>Capitolo 3</b>, i <b>Casi Studio del Capitolo 11</b> o il <b>Glossario del Capitolo 13</b>.", kind="baby"))

    # =========================================================================
    # CAPITOLO 1: LA FILOSOFIA DI AETHERSCAN-PRO
    # =========================================================================
    story.extend(chapter_header("La Filosofia di AetherScan-Pro: Perché è Diversa da Tutto il Resto", 1))
    
    story.append(Paragraph("1.1 Il Grande Problema delle Applicazioni Tradizionali", style_h2))
    story.append(Paragraph(
        "Se apri il negozio di applicazioni del tuo telefono e cerchi parole come 'Ghost Scanner', 'Rilevatore Spiritico' o 'Ghost Box', "
        "troverai centinaia di programmi apparentemente fantascientifici. Quasi tutti mostrano radar con pallini verdi che si muovono, "
        "oppure pronunciano improvvisamente parole inquietanti come <i>'morte'</i>, <i>'porta'</i>, <i>'freddo'</i>, <i>'dietro di te'</i>.",
        style_body
    ))
    story.append(Paragraph(
        "Ma come funzionano realmente quelle applicazioni dietro le quinte? <b>Nel 99% dei casi, prendono in giro l'utente.</b> "
        "All'interno del loro codice c'è un semplice elenco di parole salvate (un vocabolario da 500 a 2000 vocaboli). A intervalli regolari, "
        "un piccolo generatore di numeri casuali (chiamato in informatica <i>PRNG</i>) pesca una parola a sorte e la fa leggere alla voce sintetica del telefono.",
        style_body
    ))
    story.append(Paragraph(
        "Il cervello umano fa il resto attraverso un fenomeno psicologico chiamato <b>pareidolia</b>: se l'applicazione dice 'porta', l'utente "
        "si guarda intorno, vede una porta nella stanza e si convince che ci sia un fantasma che comunica. È una finzione commerciale che non ha "
        "nulla a che vedere con la vera indagine metrologica.",
        style_body
    ))
    story.append(Spacer(1, 4))

    story.append(Paragraph("1.2 La Svolta Metrologica di AetherScan-Pro", style_h2))
    story.append(Paragraph(
        "AetherScan-Pro è nata con un obiettivo opposto e radicale: <b>l'onestà scientifica assoluta al 100%</b>. "
        "All'interno di AetherScan-Pro:",
        style_body
    ))
    story.append(Paragraph("• <b>NON ESISTONO dizionari di parole:</b> L'applicazione non contiene nemmeno una parola preimpostata.", style_bullet))
    story.append(Paragraph("• <b>NON ESISTE sintesi vocale fasulla:</b> Il programma non pronuncerà mai frasi simulate per spaventare.", style_bullet))
    story.append(Paragraph("• <b>NON CI SONO radar finti:</b> Nessun pallino viene disegnato a schermo per simulare presenze.", style_bullet))
    story.append(Paragraph("• <b>I DATI SONO 100% REALI:</b> Se un grafico sale, è perché il magnetometro, l'accelerometro, il barometro o il microfono hanno registrato una perturbazione fisica nell'ambiente.", style_bullet))
    story.append(Spacer(1, 4))

    story.append(callout("L'ESEMPIO DELLA BILANCIA (COME SPIEGARLO A UN BAMBINO)",
        "Immagina di andare dal dottore per pesarti. Vorresti salire su una bilancia che tira a indovinare un numero a caso per farti contento, "
        "oppure su una bilancia di metallo precisa che ti dice esattamente quanti chili pesi? "
        "<b>AetherScan-Pro è quella bilancia di precisione.</b> Non ti dirà mai bugie per farti credere a qualcosa che non c'è. "
        "Ti dice solo la pura, severa verità su quello che accade nella stanza.", kind="baby"))
    story.append(Spacer(1, 6))

    story.append(Paragraph("1.3 La Metafora dell'Orchestra: Come Lavorano Insieme i Dati", style_h2))
    story.append(Paragraph(
        "Pensa ai 4 sensori del tuo smartphone come a 4 musicisti di un quartetto: c'è il violino (il magnetometro), "
        "il tamburo (l'accelerometro), il flauto (il barometro) e il cantante (il microfono).",
        style_body
    ))
    story.append(Paragraph(
        "Se il violino suona una nota isolata (ad esempio, c'è una piccola variazione magnetica perché passa un'auto in strada), "
        "non c'è nulla di speciale: è un normale rumore di fondo. "
        "Ma se all'improvviso, nello stesso esatto secondo, <b>il tamburo registra un contatto fisico sul telaio</b> e contemporaneamente <b>il violino "
        "segna un balzo magnetico enorme</b> e <b>la pressione dell'aria cambia bruscamente</b>, allora non è un caso casuale: "
        "tutta l'orchestra sta suonando all'unisono! Questa coincidenza multipla è l'unica cosa che ha valore scientifico.",
        style_body
    ))

    # =========================================================================
    # CAPITOLO 2: I 4 SENSORI FISICI DELLO SMARTPHONE
    # =========================================================================
    story.extend(chapter_header("I 4 Sensori del Telefono: Come Funzionano e Cosa Misurano", 2))
    
    story.append(Paragraph("2.1 I Veri Strumenti Nascosti nel Tuo Smartphone", style_h2))
    story.append(Paragraph(
        "Molti credono che uno smartphone sia solo uno schermo con cui guardare i social. In realtà, per poter funzionare, "
        "ogni telefono moderno racchiude al suo interno un piccolo miracolo dell'ingegneria microscopica (chiamata tecnologia MEMS): "
        "minuscoli laboratori fisici saldati sui circuiti integrati.",
        style_body
    ))
    story.append(Spacer(1, 4))

    sensor_table_data = [
        [Paragraph("<b>SENSORE FISICO</b>", style_table_header), Paragraph("<b>A COSA SERVE NEL TELEFONO</b>", style_table_header), Paragraph("<b>COSA MISURA IN AETHERSCAN-PRO</b>", style_table_header), Paragraph("<b>UNITÀ DI MISURA</b>", style_table_header)],
        [
            Paragraph("<b>1. Magnetometro</b><br/>(Sensore Bussola)", style_table_cell_bold),
            Paragraph("Fa funzionare Google Maps per capire dove si trova il Nord.", style_table_cell),
            Paragraph("Misura i campi elettromagnetici naturali e artificiali nello spazio 3D.", style_table_cell),
            Paragraph("<b>µT</b><br/>(microTesla)", style_table_cell_bold)
        ],
        [
            Paragraph("<b>2. Accelerometro</b><br/>(Inerziale a 3 assi)", style_table_cell_bold),
            Paragraph("Ruota lo schermo in orizzontale e conta i passi che fai.", style_table_cell),
            Paragraph("Misura ogni tocco, pressione o vibrazione sul telaio del telefono.", style_table_cell),
            Paragraph("<b>m/s²</b><br/>(metri al secondo²)", style_table_cell_bold)
        ],
        [
            Paragraph("<b>3. Barometro</b><br/>(Pressione Aria)", style_table_cell_bold),
            Paragraph("Aiuta il GPS a capire a che piano di un palazzo ti trovi.", style_table_cell),
            Paragraph("Registra micro-compressioni o rarefazioni dell'aria nella stanza.", style_table_cell),
            Paragraph("<b>hPa</b><br/>(hectopascal)", style_table_cell_bold)
        ],
        [
            Paragraph("<b>4. Microfono & DSP</b><br/>(Processore Audio)", style_table_cell_bold),
            Paragraph("Cattura la tua voce durante telefonate o registrazioni vocali.", style_table_cell),
            Paragraph("Analizza lo spettro sonoro separando le frequenze con filtro anti-50Hz.", style_table_cell),
            Paragraph("<b>dBFS & Hz</b><br/>(decibel & Hertz)", style_table_cell_bold)
        ],
    ]
    st_table = Table(sensor_table_data, colWidths=[105, 125, 195, 85])
    st_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(st_table)
    story.append(Spacer(1, 10))

    story.append(Paragraph("2.2 Come Preparare il Telefono sul Campo per Evitare Errori", style_h2))
    story.append(Paragraph(
        "Poiché i sensori di AetherScan-Pro sono estremamente sensibili, un posizionamento errato potrebbe farti registrare 'falsi positivi'. "
        "Ecco le 3 regole auree da seguire sempre prima di iniziare:",
        style_body
    ))
    story.append(Paragraph("1. <b>RIMUOVI COVER CON MAGNETI O ANELLI IN METALLO:</b> Molte custodie moderne per smartphone hanno una piastrina metallica o un magnete sul retro per attaccarsi ai supporti dell'auto. Se lasci quella custodia, il magnetometro registrerà valori altissimi e falsati! Usa una custodia in silicone semplice o lascia il telefono nudo.", style_bullet))
    story.append(Paragraph("2. <b>APPOGGIA IL TELEFONO SU UN SUPPORTO FERMO:</b> Non tenere il telefono in mano mentre fai monitoraggio metrologico. La tua mano trema impercettibilmente, il tuo sangue pulsa e il metallo degli anelli o dell'orologio disturba i sensori. Metti il telefono su un treppiede in plastica/legno o su un tavolo stabile.", style_bullet))
    story.append(Paragraph("3. <b>ATTENZIONE ALLE TASCHE E AGLI SMARTWATCH:</b> Gli orologi digitali (Apple Watch, smartwatch) hanno un caricatore a induzione magnetica sul retro. Se avvicini il polso al telefono, il magnetometro schizzerà alle stelle. Mantieni sempre almeno 50 cm di distanza.", style_bullet))
    story.append(Spacer(1, 4))

    story.append(callout("COSA PUÒ FARE IL TELEFONO E COSA NO (I LIMITI FISICI)",
        "Il tuo smartphone è straordinario, ma non ha bacchette magiche. Non può 'fotografare ectoplasmi' o 'ricevere messaggi vocali dall'aldilà'. "
        "Quello che fa è misurare la fisica dell'ambiente: se un'entità interagisce con il mondo reale, <b>deve</b> lasciare una traccia fisica "
        "(spostare calore, alterare il campo magnetico, far vibrare una superficie o comprimere l'aria). "
        "Se c'è una traccia fisica reale, AetherScan-Pro la cattura e la certifica. Se non c'è traccia fisica, l'app rimane rigorosamente in silenzio.", kind="amber"))

    # =========================================================================
    # CAPITOLO 3: LA SCHERMATA METROLOGY PRO
    # =========================================================================
    story.extend(chapter_header("Schermata 1: Metrology Pro – Come Leggere Ogni Singolo Valore", 3))
    
    # Inserimento della figura dello screenshot Metrology Pro
    fig_metro_bullets = [
        "<b>BARRA IN ALTO:</b> Menu Hamburger ☰, Logo v27-beta2, Pillola [ UNCALIBRATED ]/[ CALIBRATED ], Tasto Regolazioni 🎛️ e Scudo Forense SHA-256 🛡️.",
        "<b>RIQUADRO EMF (in alto a sx):</b> Misura il campo magnetico in microTesla (48.8 µT). Mostra il Delta (+0.0) e lo Z-Score (Z=0.0).",
        "<b>RIQUADRO VIBRAZIONE (in alto a dx):</b> Accelerometro a 3 assi. Segna 0.00 m/s² e la scritta verde STATO FERMO. Diventa rossa in caso di urto.",
        "<b>RIQUADRO PRESSIONE (in basso a sx):</b> Barometro in hPa (1013.3 hPa). Monitora la stabilità della colonna d'aria nella stanza.",
        "<b>RIQUADRO AUDIO (in basso a dx):</b> SNR e Picco di frequenza (4125 Hz a -84 dBFS). Filtro Notch a 50Hz attivo per eliminare la corrente di casa.",
        "<b>OSCILLOSCOPIO VETTORIALE:</b> Griglia blu inferiore con traccia d'onda continua campionata in tempo reale a 30Hz.",
        "<b>TASTI FORENSI IN FONDO:</b> [ CSV RFC 4180 ] e [ JSON FORENSE ] per il salvataggio immediato dei dati."
    ]
    story.append(figure_card(p_metrology, "La Plancia Metrology Pro", fig_metro_bullets, max_w=175, max_h=190))
    story.append(Spacer(1, 8))

    story.append(Paragraph("3.1 Dettaglio Riquadro EMF: Cos'è il microTesla e lo Z-Score", style_h2))
    story.append(Paragraph(
        "Nel riquadro in alto a sinistra trovi la telemetria del campo elettromagnetico:",
        style_body
    ))
    story.append(Paragraph("• <b>48.8 µT (microTesla):</b> È l'intensità totale del campo. In natura, la Terra genera tra 35 e 55 µT. Un valore compreso in questo intervallo è perfettamente normale e fisiologico.", style_bullet))
    story.append(Paragraph("• <b>Δ +0.0 (Delta):</b> Indica di quanto il valore si è spostato rispetto alla media calcolata per la stanza. Se è 0.0, l'ambiente è perfettamente stabile.", style_bullet))
    story.append(Paragraph("• <b>Z=0.0 (Z-Score):</b> È il punteggio statistico di anomalia. Misura quante deviazioni standard dista la misura dalla quiete normale.", style_bullet))
    story.append(Spacer(1, 4))

    story.append(callout("COME CAPIRE LO Z-SCORE (L'ESEMPIO DELL'ALTEZZA A SCUOLA)",
        "Immagina una classe di bambini di 10 anni: l'altezza media è 140 cm. Se arriva un bambino alto 142 cm, nessuno ci fa caso (Z-Score vicino a 0.5). "
        "Se arriva un bambino alto 155 cm, è un po' più alto della media ma capita (Z-Score = 2.0). "
        "Ma se all'improvviso entra in classe un bambino alto <b>2 metri e 10 centimetri</b>, tutta la scuola si ferma a bocca aperta! "
        "Quel bambino alto 2 metri e 10 è un evento con <b>Z-Score ≥ 3.5σ</b>: una deviazione così gigantesca e rara che non può essere spiegata dal caso (probabilità inferiore allo 0.05%). "
        "Quando vedi <b>Z ≥ 3.5</b> su AetherScan-Pro, sai con certezza matematica che sta accadendo qualcosa di eccezionale!", kind="baby"))
    story.append(Spacer(1, 8))

    story.append(Paragraph("3.2 Dettaglio Riquadro Vibrazione: Smascherare i Falsi Urti", style_h2))
    story.append(Paragraph(
        "Nel riquadro in alto a destra, l'accelerometro controlla costantemente lo stato fisico dello smartphone in metri al secondo quadrato (<b>m/s²</b>). "
        "La gravità terrestre (pari a 9.81 m/s²) viene rimossa matematicamente attraverso un filtro vettoriale, lasciando solo l'accelerazione dinamica reale:",
        style_body
    ))
    story.append(Paragraph("• <b>0.00 m/s² STATO FERMO (Verde):</b> Il telefono riposa immobile.", style_bullet))
    story.append(Paragraph("• <b>Valori > 3.2 m/s² URTO MECCANICO (Rosso):</b> Il telaio ha subito una spinta, una pressione o un colpo deciso.", style_bullet))
    story.append(Paragraph(
        "Questa scheda è il guardiano anti-frode dell'applicazione: se qualcuno muove il tavolo o scuote il telefono, la scritta rossa si accende "
        "e blocca all'istante l'allarme sonoro, salvando nel registro che si è trattato di un semplice contatto meccanico.",
        style_body
    ))
    story.append(Spacer(1, 8))

    story.append(Paragraph("3.3 Dettaglio Barometro e Audio Peak", style_h2))
    story.append(Paragraph(
        "I due riquadri inferiori completano il quadro ambientale:<br/>"
        "• <b>Pressione (1013.3 hPa):</b> Segnala 'Stato Atmosferico' stabile. Monitora se si verificano depressioni o sovrappressioni locali d'aria.<br/>"
        "• <b>Audio Peak (4125 Hz a -84 dBFS):</b> Il DSP campiona il rumore ambientale attraverso un filtro Biquad Notch che <b>abbatte di oltre 40 dB il ronzio a 50Hz dei cavi elettrici</b>. "
        "Così facendo, l'app non viene accecata dall'impianto di casa e può isolare frequenze anomale nel silenzio.",
        style_body
    ))

    # =========================================================================
    # CAPITOLO 4: LA CALIBRAZIONE DELLA BASELINE (30 SECONDI)
    # =========================================================================
    story.extend(chapter_header("La Calibrazione di 30 Secondi e l'Algoritmo di Welford", 4))
    
    fig_calib_bullets = [
        "<b>TITOLO IN AMBRA:</b> CALIBRAZIONE BASELINE - Profilazione del rumore stazionario dell'edificio.",
        "<b>CONTO ALLA ROVESCIA (29s):</b> Timer decrescente che dura esattamente 30 secondi per campionare centinaia di letture.",
        "<b>BARRA DI AVANZAMENTO:</b> Si riempie in arancione indicando la percentuale di completamento.",
        "<b>DATI CAMPIONATI:</b> Mostra il contatore campioni (es. Campioni acquisiti: 6) elaborati istante per istante con l'Algoritmo di Welford.",
        "<b>TASTO ANNULLA:</b> Permette di bloccare la procedura in qualsiasi istante senza conseguenze se il tavolo viene urtato."
    ]
    story.append(figure_card(p_calib, "L'Overlay di Calibrazione 30 Secondi", fig_calib_bullets, max_w=165, max_h=230))
    story.append(Spacer(1, 8))

    story.append(Paragraph("4.1 Perché la Calibrazione non è più Invasiva all'Avvio", style_h2))
    story.append(Paragraph(
        "In precedenza, l'applicazione apriva forzatamente questa schermata appena avviavi l'app. "
        "Nella versione v27-beta2, su richiesta degli operatori sul campo, la calibrazione automatica iniziale è stata rimossa: "
        "l'app carica immediatamente una <b>Baseline Standard Terrestre</b> (42.0 µT e 1013.25 hPa) ed è subito utilizzabile. "
        "Sei tu a decidere quando avviare la profilazione precisa della stanza toccando l'icona con i cursori (🎛️) nella barra in alto.",
        style_body
    ))
    story.append(Spacer(1, 6))

    story.append(Paragraph("4.2 L'Algoritmo di Welford Spiegato Semplice", style_h2))
    story.append(Paragraph(
        "Durante i 30 secondi di calibrazione, lo smartphone raccoglie oltre 1000 misurazioni consecutive. "
        "Invece di riempire la memoria del telefono e rallentare il sistema, l'app usa l'<b>Algoritmo di Welford</b>, "
        "che ricalcola la media e la varianza istantaneamente a ogni singolo campione:",
        style_body
    ))
    
    welford_code = """
    // Algoritmo di Welford M2 implementato in baseline_engine.dart:
    count += 1;
    delta = current_sample - mean;
    mean  += delta / count;
    delta2 = current_sample - mean;
    M2    += delta * delta2;
    variance = M2 / (count - 1);
    standard_deviation = sqrt(variance);
    """
    story.append(Paragraph(f"<pre>{welford_code}</pre>", style_code))
    story.append(Spacer(1, 4))

    story.append(callout("L'ESEMPIO DEL SALVADANAIO (SPIEGATO A UN BAMBINO)",
        "Immagina di voler sapere quanti soldi metti in media nel salvadanaio ogni giorno. "
        "Un metodo noioso sarebbe scrivere ogni moneta su un quaderno per 30 giorni e poi fare una somma gigantesca alla fine. "
        "L'algoritmo di Welford è come un salvadanaio magico con un piccolo pallottoliere sul coperchio: ogni volta che infili una moneta, "
        "lui sposta una pallina e ricalcola all'istante la media perfetta senza dover tenere montagne di scontrini. "
        "Così il tuo telefono non si blocca mai e resta velocissimo!", kind="baby"))

    # =========================================================================
    # CAPITOLO 5: IL DOPPIO TRIGGER FISICO E L'ALLARME ACUSTICO
    # =========================================================================
    story.extend(chapter_header("Il Doppio Trigger Fisico e l'Allarme Sonoro", 5))
    
    story.append(Paragraph("5.1 La Verità Definitiva sull'Audio (Basta Fraintendimenti!)", style_h2))
    story.append(Paragraph(
        "Vogliamo ribadire con la massima trasparenza forense la vera natura dell'audio in AetherScan-Pro. "
        "Molti utenti nelle prime sessioni chiedevano: <i>'Ma quella risata o quel suono è una voce di spirito?'</i>",
        style_body
    ))
    story.append(Paragraph(
        "<b>La risposta è un categorico NO.</b> Il file audio caricato nell'applicazione (che sia una risata cupa, un cicalino, un beep "
        "o una sirena) non è altro che un <b>campione audio di notifica d'allarme</b>, esattamente identico al cicalino di un allarme antincendio "
        "o alla sirena di una cassaforte. L'operatore può scegliere il file audio che preferisce per avere un feedback acustico immediato quando si trova al buio, "
        "senza dover tenere gli occhi incollati allo schermo.",
        style_body
    ))
    story.append(Spacer(1, 6))

    story.append(Paragraph("5.2 La Regola Ferrea del 'Due in Uno' (Coincidenza Simultanea)", style_h2))
    story.append(Paragraph(
        "In AetherScan-Pro v2.0 abbiamo implementato in <code>trigger_logic.dart</code> una <b>doppia validazione simultanea ferrea</b>. "
        "Il suono di allarme ha il divieto assoluto di partire a meno che non si verifichino contemporaneamente due condizioni fisiche verificate sul campo:",
        style_body
    ))
    story.append(Paragraph("• <b>CONDIZIONE 1 (Contatto Meccanico Reale):</b> L'accelerometro a 3 assi deve rilevare un contatto fisico reale sul telaio dello smartphone con accelerazione dinamica <b>|A_dyn| ≥ 3.2 m/s²</b>.", style_bullet))
    story.append(Paragraph("• <b>CONDIZIONE 2 (Anomalia Metrologica Severa):</b> Nello stesso istante, il magnetometro deve registrare una deviazione statistica eccezionale con <b>Z-Score ≥ 3.5σ</b> (confidenza > 99.95%).", style_bullet))
    story.append(Spacer(1, 6))

    trigger_table_data = [
        [Paragraph("<b>COSA SUCCEDE SUL CAMPO</b>", style_table_header), Paragraph("<b>STATO SENSORI</b>", style_table_header), Paragraph("<b>AZIONE DI AETHERSCAN-PRO</b>", style_table_header), Paragraph("<b>L'ALLARME PARTE?</b>", style_table_header)],
        [
            Paragraph("<b>Scenario 1:</b><br/>Tutto calmo nella stanza.", style_table_cell_bold),
            Paragraph("Accel: 0.0 m/s²<br/>EMF: Z = 0.2σ (normale)", style_table_cell),
            Paragraph("Monitoraggio quieto continuo. Nessuna anomalia.", style_table_cell),
            Paragraph("<b>NO (Silenzio assoluto)</b>", style_table_cell_bold)
        ],
        [
            Paragraph("<b>Scenario 2:</b><br/>Qualcuno urta il tavolo o tocca il telefono.", style_table_cell_bold),
            Paragraph("Accel: 4.5 m/s² (URTO)<br/>EMF: Z = 0.4σ (normale)", style_table_cell),
            Paragraph("Segnala a schermo 'URTO MECCANICO' in rosso. Registra nel log l'urto per scartarlo.", style_table_cell),
            Paragraph("<b>NO (Silenzio assoluto)<br/>Falso allarme bloccato!</b>", style_table_cell_bold)
        ],
        [
            Paragraph("<b>Scenario 3:</b><br/>Si accende un frigo o passa un'auto.", style_table_cell_bold),
            Paragraph("Accel: 0.0 m/s² (Fermo)<br/>EMF: Z = 4.1σ (Anomalia)", style_table_cell),
            Paragraph("Registra nel file CSV l'anomalia magnetica pura con timestamp ISO. Nessuna interazione fisica.", style_table_cell),
            Paragraph("<b>NO (Silenzio assoluto)<br/>Nessuna illusione acustica</b>", style_table_cell_bold)
        ],
        [
            Paragraph("<b>Scenario 4 (CONFERMA FORENSE):</b><br/>Tocco fisico sul telaio E contemporaneamente anomalia magnetica eccezionale!", style_table_cell_bold),
            Paragraph("Accel: 3.8 m/s² (Tocco)<br/>EMF: Z = 4.8σ (Anomalia)", style_table_cell),
            Paragraph("<b>DUAL-TRIGGER CONFERMATO:</b> L'evento viene marcato con flag speciale nel file CSV e certificato con hash SHA-256.", style_table_cell),
            Paragraph("<b>SÌ! SCATTA IL SEGNALE ACUSTICO DI ALLARME!</b>", style_table_cell_bold)
        ],
    ]
    tt_t = Table(trigger_table_data, colWidths=[110, 115, 165, 121])
    tt_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('BACKGROUND', (0,4), (-1,4), c_green_light),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(tt_t)
    story.append(Spacer(1, 8))

    story.append(callout("FINESTRA DI COINCIDENZA (250ms) E COOLDOWN (1500ms)",
        "Affinché l'allarme scatti, l'urto e l'anomalia magnetica devono manifestarsi entro una finestra temporale massima di <b>250 millisecondi</b> (un quarto di secondo). "
        "Una volta scattato l'allarme, il sistema entra in una pausa di sicurezza (Cooldown) di <b>1500 millisecondi</b> (1,5 secondi) per impedire "
        "che il suono si ripeta all'infinito a raffica gracchiando o rovinando la registrazione audio.", kind="amber"))

    # =========================================================================
    # CAPITOLO 6: IL MENU DRAWER DI NAVIGAZIONE
    # =========================================================================
    story.extend(chapter_header("Il Drawer di Navigazione: Passare tra le Modalità", 6))
    
    fig_drawer_bullets = [
        "<b>APERTURA DEL DRAWER:</b> Toccando le tre linee in alto a sinistra (☰) compare questo cassetto laterale senza interrompere il campionamento dei sensori.",
        "<b>MODALITÀ 1 - METROLOGY PRO:</b> La suite scientifica severa con grafici puri, Z-Score ≥ 3.5σ, log forense RFC 4180 CSV con SHA-256 e doppio trigger.",
        "<b>MODALITÀ 2 - AM/FM SPECTRAL SWEEP:</b> Scansione radio live accoppiata in tempo reale ai sensori fisici. Zero dizionari o voci simulate.",
        "<b>TASTO RAPIDO DI CALIBRAZIONE:</b> Pulsante arancione [ AVVIA CALIBRAZIONE (30s) ] accessibile in qualsiasi momento anche dall'interno del menu."
    ]
    story.append(figure_card(p_drawer, "Il Drawer di Selezione Modalità", fig_drawer_bullets, max_w=175, max_h=190))
    story.append(Spacer(1, 8))

    story.append(Paragraph("6.1 Due Mondi Perfettamente Integrati in Un'Unica App", style_h2))
    story.append(Paragraph(
        "Grazie a questo menu di navigazione intuitivo, hai a disposizione due strumenti professionali in un unico software:<br/>"
        "1. <b>Quando vuoi lavorare da scienziato o perito:</b> tieni attiva la modalità <i>Metrology Pro</i>, lasci il telefono sul treppiede e registri i file CSV firmati crittograficamente.<br/>"
        "2. <b>Quando sei in diretta streaming o vuoi un riscontro audio dinamico:</b> passi a <i>Spectral Sweep</i>, godendoti la sintonia stile radio vintage e l'interazione sensoriale in tempo reale.",
        style_body
    ))

    # =========================================================================
    # CAPITOLO 7: SCHERMATA AM/FM SPECTRAL SWEEP
    # =========================================================================
    story.extend(chapter_header("Schermata 2: AM/FM Spectral Sweep – La Radio Live", 7))
    
    fig_sweep_fm_bullets = [
        "<b>FREQUENZA DIGITALE:</b> Cifre giganti bianche (es. 90.6 MHz) con indicatore di banda verde ciano (FM VHF 87.5 - 108 MHz).",
        "<b>INDICATORE S-METER:</b> Barra azzurra di intensità con lettura in dBm (es. S2 -115 dBm).",
        "<b>SCALA ANALOGICA VINTAGE:</b> Scala graduata con ago rosso mobile che si sposta a destra o a sinistra durante la scansione.",
        "<b>ANALISI SPETTRALE DSP:</b> Grafico a barre ciano che analizza il rumore del microfono ed estrae la frequenza di picco istantanea (es. 12563 Hz).",
        "<b>EMF REATTIVO E MODULAZIONE %:</b> Mostra il campo magnetico reale e quanta influenza fisica sta modulando il flusso sonoro.",
        "<b>PANNELLO DI CONTROLLO INFERIORE:</b> Tasti Banda FM/AM, selettore velocità (Rate da 50ms a 500ms), Tasto Pausa e Tasti Direzione."
    ]
    story.append(figure_card(p_sweep_fm, "Spectral Sweep in Banda FM (VHF)", fig_sweep_fm_bullets, max_w=165, max_h=230))
    story.append(Spacer(1, 8))

    story.append(Paragraph("7.1 Come Funziona la Scansione Radio Scientifica", style_h2))
    story.append(Paragraph(
        "Mentre le Spirit Box commerciali saltano su stazioni radio commerciali trasmesse via etere ingannando chi ascolta, "
        "lo <b>Spectral Sweep di AetherScan-Pro</b> genera una frequenza portante virtuale su cui applica un flusso di rumore bianco pulito. "
        "Questo flusso viene alterato <b>esclusivamente</b> dalle variazioni reali dei sensori (magnetometro e accelerometro):",
        style_body
    ))
    story.append(Paragraph("• Se l'ambiente è calmo (EMF normale e telaio stabile), senti solo il fruscio rilassante e continuo della radio.", style_bullet))
    story.append(Paragraph("• Se si verifica una perturbazione magnetica reale, il parametro <b>MODULAZIONE %</b> sale e il DSP rimodella la risonanza del suono in tempo reale, segnalando l'anomalia all'orecchio dell'operatore.", style_bullet))
    story.append(Spacer(1, 6))

    fig_sweep_am_bullets = [
        "<b>BANDA AM (MW):</b> Scansione sulle frequenze da 530 a 1600 kHz (es. 600 kHz) con passo standard di 10 kHz.",
        "<b>I DUE TASTI DIREZIONALI SEPARATI:</b> In fondo a destra sono ora ben visibili sia il tasto [ REV ◀ ] (ambra) per scorrere a ritroso, sia il tasto [ FWD ▶ ] (ciano) per scorrere in avanti.",
        "<b>TASTO PAUSA SWEEP:</b> Permette di arrestare la corsa della frequenza su un canale specifico per un ascolto prolungato.",
        "<b>ETICHETTA FORENSE IN FONDO:</b> 'ZERO DIZIONARI O GENERATORI CASUALI. Modulazione reattiva unicamente ai sensori fisici.'"
    ]
    story.append(figure_card(p_sweep_am, "Spectral Sweep in Banda AM (MW) con Nuovi Tasti REV/FWD", fig_sweep_am_bullets, max_w=165, max_h=230))
    story.append(Spacer(1, 8))

    story.append(callout("GUIDA AI CONTROLLI DI VELOCITÀ (RATE CHIPS)",
        "Nella riga <b>RATE</b> puoi selezionare la velocità di scansione dei passi di frequenza:<br/>"
        "• <b>50ms (Ultra-Rapido):</b> 20 frequenze al secondo. Molto ritmico, ideale per scansioni veloci in ambienti rumorosi.<br/>"
        "• <b>100ms (Standard Consigliato):</b> 10 frequenze al secondo. Il perfetto equilibrio tra dinamismo e chiarezza acustica.<br/>"
        "• <b>200ms / 300ms (Medio):</b> Scansione cadenzata che permette all'orecchio di apprezzare ogni singola variazione spettrale.<br/>"
        "• <b>500ms (Lento):</b> Mezzo secondo per frequenza. Ideale per meditazione o lunghe sessioni statiche.", kind="info"))

    # =========================================================================
    # CAPITOLO 8: LA CATENA FORENSE, IL CODICE HASH SHA-256 E I LOG
    # =========================================================================
    story.extend(chapter_header("La Catena Forense, l'Hash SHA-256 e i File di Log", 8))
    
    fig_hash_bullets = [
        "<b>SCUDO FORENSE:</b> Finestra modale che compare toccando lo scudo celeste nella barra superiore.",
        "<b>DIGEST CRITTOGRAFICO SHA-256:</b> Codice alfanumerico univoco a 64 caratteri (es. d095d9c3b57937c03d1b8274dad985c351452afcc73482bcbf78748706c491d6).",
        "<b>HARDWARE ID (HWID):</b> Identificativo univoco del dispositivo per garantire la provenienza dell'apparecchio.",
        "<b>EVENTI VALIDATI & ARTEFATTI:</b> Contatore in tempo reale degli eventi fisici certificati e degli urti scartati.",
        "<b>TASTO [ COPIA HASH ]:</b> Copia l'impronta negli appunti con un tocco, pronta per essere incollata nella descrizione di un video o in una perizia."
    ]
    story.append(figure_card(p_hash, "L'Impronta Digitale Forense SHA-256", fig_hash_bullets, max_w=170, max_h=210))
    story.append(Spacer(1, 8))

    story.append(Paragraph("8.1 Come Funziona l'Impronta Digitale SHA-256", style_h2))
    story.append(Paragraph(
        "Nel mondo scientifico e giudiziario, quando si raccolgono prove digitali è fondamentale garantire che nessuno abbia "
        "manomesso il file a posteriori aggiungendo numeri inventati o cancellando dati scomodi.",
        style_body
    ))
    story.append(Paragraph(
        "AetherScan-Pro integra un motore crittografico SHA-256 in tempo reale: ogni volta che un campione viene acquisito, "
        "il dato entra in un frullatore matematico irreversibile. "
        "Se una persona apre il file CSV ed esegue il calcolo dell'hash con qualsiasi programma di verifica (come Windows PowerShell o Linux), "
        "otterrà esattamente la stessa identica stringa di 64 caratteri.",
        style_body
    ))
    story.append(Spacer(1, 4))

    story.append(callout("L'ESEMPIO DEL SIGILLO IN CERALACCA (SPIEGATO A UN BAMBINO)",
        "Nei tempi antichi, quando il Re scriveva una lettera segreta, metteva sulla busta una goccia di ceralacca rossa e ci premeva sopra "
        "il suo anello d'oro. Se qualcuno per strada provava ad aprire la busta anche solo per sbirciare mezza parola, il sigillo si rompeva "
        "e il Re scopriva subito il tradimento!<br/><br/>"
        "<b>Il codice HASH SHA-256 è il sigillo di ceralacca digitale del tuo smartphone:</b> basta cambiare un solo millesimo di secondo, "
        "una virgola o un decimale in tutto il file registrato, e l'intero codice HASH cambia completamente diventando irriconoscibile. "
        "Se condividi l'hash all'inizio del video o nella descrizione, <b>nessuno al mondo potrà mai accusarti di aver taroccato i dati!</b>", kind="baby"))

    # =========================================================================
    # CAPITOLO 9: GUIDA AD EXCEL E CREAZIONE GRAFICI
    # =========================================================================
    story.extend(chapter_header("Guida ad Excel e Creazione dei Grafici Forensi", 9))
    
    story.append(Paragraph("9.1 Come Aprire il File CSV sul Computer", style_h2))
    story.append(Paragraph(
        "Dopo aver toccato il tasto <b>[ CSV RFC 4180 ]</b> in fondo allo schermo, troverai sul tuo telefono un file con nome simile a:<br/>"
        "<code>AetherScan_Session_20261115_151402.csv</code>.<br/>"
        "Puoi inviarlo via email o copialo sul computer tramite cavo USB. Fai doppio clic per aprirlo con Microsoft Excel, Google Fogli o LibreOffice Calc.",
        style_body
    ))
    story.append(Spacer(1, 6))

    story.append(Paragraph("9.2 Struttura Dettagliata di Ogni Singola Colonna", style_h2))
    
    csv_cols_data = [
        [Paragraph("<b>COLONNA CSV</b>", style_table_header), Paragraph("<b>NOME TECNICO</b>", style_table_header), Paragraph("<b>COSA SIGNIFICA E COME INTERPRETARLA</b>", style_table_header)],
        [Paragraph("<b>A</b>", style_table_cell_bold), Paragraph("<code>timestamp_iso</code>", style_code), Paragraph("Data e ora esatta al millesimo di secondo (UTC/ISO 8601). Esempio: <code>2026-11-15T15:14:02.124Z</code>.", style_table_cell)],
        [Paragraph("<b>B</b>", style_table_cell_bold), Paragraph("<code>session_ms</code>", style_code), Paragraph("Millisecondi trascorsi dall'inizio della registrazione (utile per sincronizzare i dati con l'audio del video della telecamera).", style_table_cell)],
        [Paragraph("<b>C, D, E</b>", style_table_cell_bold), Paragraph("<code>emf_x, emf_y, emf_z</code>", style_code), Paragraph("I tre vettori spaziali del magnetometro in microTesla. Indicano da quale direzione fisica arrivava la forza.", style_table_cell)],
        [Paragraph("<b>F</b>", style_table_cell_bold), Paragraph("<code>emf_mag_uT</code>", style_code), Paragraph("Il modulo totale risultante: √(x² + y² + z²). È il valore complessivo mostrato a caratteri giganti a schermo.", style_table_cell)],
        [Paragraph("<b>G</b>", style_table_cell_bold), Paragraph("<code>accel_dyn_ms2</code>", style_code), Paragraph("Accelerazione dinamica sul telaio in m/s². Se è zero il telefono era immobile; se > 3.2 indica un urto.", style_table_cell)],
        [Paragraph("<b>H</b>", style_table_cell_bold), Paragraph("<code>pressure_hpa</code>", style_code), Paragraph("Pressione atmosferica in hectopascal (normale ~1013.25 hPa).", style_table_cell)],
        [Paragraph("<b>I</b>", style_table_cell_bold), Paragraph("<code>audio_dbfs</code>", style_code), Paragraph("Volume acustico in decibel full-scale (da -90 silenzio a 0 saturazione microfonica).", style_table_cell)],
        [Paragraph("<b>J</b>", style_table_cell_bold), Paragraph("<code>audio_peak_hz</code>", style_code), Paragraph("Frequenza audio dominante in Hertz calcolata con l'algoritmo FFT.", style_table_cell)],
        [Paragraph("<b>K</b>", style_table_cell_bold), Paragraph("<code>z_score_emf</code>", style_code), Paragraph("Deviazione statistica rispetto alla quiete della stanza. Se ≥ 3.5σ segna un'anomalia autentica.", style_table_cell)],
        [Paragraph("<b>L</b>", style_table_cell_bold), Paragraph("<code>event_flag</code>", style_code), Paragraph("Stato forense dell'evento: <b>QUIESCENT</b> (quiete), <b>MECHANICAL_BUMP</b> (urto scartato), <b>METROLOGICAL_ANOMALY</b> (anomalia magnetica pura), <b>CONFIRMED_DUAL_COINCIDENCE</b> (evento confermato!).", style_table_cell)],
    ]
    csv_t = Table(csv_cols_data, colWidths=[35, 120, printable_width - 155])
    csv_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(csv_t)
    story.append(Spacer(1, 10))

    story.append(Paragraph("9.3 Come Creare Grafici a Prova di Scettico in 3 Passaggi", style_h2))
    story.append(Paragraph(
        "1. <b>Seleziona le Colonne B (session_ms) e F (emf_mag_uT):</b> Vai nel menu <i>Inserisci -> Grafico a Linee</i>. "
        "Vedrai una linea orizzontale che rappresenta la quiete dell'ambiente, con eventuali picchi verticali ben visibili.<br/>"
        "2. <b>Filtra la Colonna L (event_flag):</b> Clicca sull'icona del filtro in Excel e togli la spunta a <i>QUIESCENT</i>. "
        "In un attimo la tabella nasconderà le migliaia di righe noiose e ti mostrerà solo ed esclusivamente i secondi esatti in cui è successo qualcosa di anomalo!<br/>"
        "3. <b>Sovrapponi la Traccia Video:</b> Poiché la colonna <i>session_ms</i> parte da zero all'inizio della sessione, puoi far coincidere al millisecondo "
        "la clip video registrata dalla tua telecamera con i dati del file CSV. Se nel video si sente un rumore strano e nello stesso millisecondo il file CSV "
        "mostra un picco Z ≥ 3.5σ con accelerometro a zero, <b>la prova scientifica è blindata al 100%!</b>",
        style_body
    ))

    # =========================================================================
    # CAPITOLO 10: VADEMECUM PRATICO SUL CAMPO
    # =========================================================================
    story.extend(chapter_header("Vademecum Pratico sul Campo: Guida per l'Operatore", 10))
    
    story.append(Paragraph("10.1 I 10 Errori più Comuni del Principiante da Evitare Assolutamente", style_h2))
    
    mistakes_data = [
        [Paragraph("<b>ERRORE COMUNE</b>", style_table_header), Paragraph("<b>PERCHÉ È SBAGLIATO</b>", style_table_header), Paragraph("<b>LA SOLUZIONE CORRETTA</b>", style_table_header)],
        [
            Paragraph("1. Tenere il telefono in mano camminando", style_table_cell_bold),
            Paragraph("La mano trema e il movimento genera continui urti meccanici e falsi positivi.", style_table_cell),
            Paragraph("Appoggia lo smartphone su un tavolo solido o su un cavalletto in legno/plastica.", style_table_cell)
        ],
        [
            Paragraph("2. Calibrare vicino a una presa di corrente", style_table_cell_bold),
            Paragraph("I cavi murati generano un campo a 50Hz che inquina la baseline iniziale.", style_table_cell),
            Paragraph("Posiziona il dispositivo ad almeno 1 metro di distanza da prese, quadri elettrici o frigo.", style_table_cell)
        ],
        [
            Paragraph("3. Dimenticare lo smartwatch al polso", style_table_cell_bold),
            Paragraph("Avvicinare il polso allo smartphone durante l'indagine fa schizzare il magnetometro per colpa dell'orologio.", style_table_cell),
            Paragraph("Togli l'orologio e mantieni le mani lontane dal raggio di 50 cm dal telefono.", style_table_cell)
        ],
        [
            Paragraph("4. Gridare vicino al microfono", style_table_cell_bold),
            Paragraph("Le grida mandano in saturazione il microfono (0 dBFS) distorcendo lo spettro FFT.", style_table_cell),
            Paragraph("Parla con tono di voce pacato e normale, lasciando che l'app ascolti l'ambiente.", style_table_cell)
        ],
        [
            Paragraph("5. Credere che l'allarme sia una voce", style_table_cell_bold),
            Paragraph("Induce in pareidolia e fa perdere qualsiasi credibilità di fronte al pubblico.", style_table_cell),
            Paragraph("Spiega chiaramente agli spettatori che il suono è una <b>sirena d'avviso</b> che certifica una doppia anomalia fisica reale.", style_table_cell)
        ],
        [
            Paragraph("6. Dimenticare il Wi-Fi o Bluetooth acceso", style_table_cell_bold),
            Paragraph("I chip radio interni trasmettono 'pacchetti beacon' che possono indurre picchi spuri.", style_table_cell),
            Paragraph("Metti il telefono in Modalità Aereo se non stai conducendo una live streaming.", style_table_cell)
        ],
        [
            Paragraph("7. Usare supporti metallici", style_table_cell_bold),
            Paragraph("Treppiedi con viti di ferro non schermate possono distorcere le linee magnetiche.", style_table_cell),
            Paragraph("Usa supporti in plastica rigida, fibra di carbonio o legno.", style_table_cell)
        ],
    ]
    mis_t = Table(mistakes_data, colWidths=[120, 160, printable_width - 280])
    mis_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_amber),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 4.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4.5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(mis_t)
    story.append(Spacer(1, 10))

    story.append(Paragraph("10.2 Il Protocollo delle 3 Stanze (Come Condurre un'Indagine Perfetta)", style_h2))
    story.append(Paragraph(
        "Non limitarti mai a fare una misurazione in una sola stanza. Per avere una validità scientifica inattaccabile, "
        "applica il <b>Protocollo delle 3 Stanze</b>:",
        style_body
    ))
    story.append(Paragraph("• <b>STANZA ZERO (Stanza di Controllo):</b> Inizia eseguendo una calibrazione e un monitoraggio di 5 minuti in una stanza neutra e tranquilla dove non sono mai stati segnalati fenomeni. Questo ti dà il 'metro di paragone' dell'edificio.", style_bullet))
    story.append(Paragraph("• <b>STANZA BERSAGLIO (Il Luogo dell'Indagine):</b> Spostati nella stanza calda. Esegui una nuova calibrazione di 30 secondi. Monitora per almeno 20-30 minuti confrontando i valori con la Stanza Zero.", style_bullet))
    story.append(Paragraph("• <b>STANZA ESTERNA (Controllo Ambientale):</b> Termina la sessione verificando i valori all'esterno dell'edificio per escludere tempeste solari, cantieri stradali o campi elettromagnetici esterni.", style_bullet))

    # =========================================================================
    # CAPITOLO 11: 20 CASI STUDIO REALI SUL CAMPO
    # =========================================================================
    story.extend(chapter_header("20 Casi Studio Reali Risolti sul Campo", 11))
    story.append(Paragraph(
        "Ecco una guida pratica per capire all'istante cosa sta succedendo sul tuo display in 20 situazioni tipiche che incontrerai sul campo:",
        style_body
    ))
    story.append(Spacer(1, 4))

    cases_data = [
        [Paragraph("<b>#</b>", style_table_header), Paragraph("<b>COSA VEDI A SCHERMO</b>", style_table_header), Paragraph("<b>DIAGNOSI METROLOGICA</b>", style_table_header), Paragraph("<b>COSA DEVI FARE / ANNOTARE</b>", style_table_header)],
        [Paragraph("1", style_table_cell_bold), Paragraph("EMF 48 µT, Accel 0.0, Baro 1013, Audio -84 dBFS", style_table_cell), Paragraph("Ambiente in perfetta quiete naturale.", style_table_cell), Paragraph("Tutto tace, continua a monitorare tranquillamente.", style_table_cell)],
        [Paragraph("2", style_table_cell_bold), Paragraph("Accel schizza a 5.2 m/s² (Rosso), EMF stabile (Z=0.1)", style_table_cell), Paragraph("Urto meccanico puro (qualcuno ha urtato il tavolo).", style_table_cell), Paragraph("Allarme giustamente muto. Ignora l'urto, è falso allarme.", style_table_cell)],
        [Paragraph("3", style_table_cell_bold), Paragraph("EMF schizza a 95 µT (Z=5.2σ), Accel 0.0 m/s² (Fermo)", style_table_cell), Paragraph("Anomalia magnetica pura senza contatto fisico.", style_table_cell), Paragraph("Registrata nel CSV. Cerca se ci sono cavi sotto il pavimento.", style_table_cell)],
        [Paragraph("4", style_table_cell_bold), Paragraph("Accel 4.1 m/s² (Rosso) E simultaneamente EMF Z=4.9σ", style_table_cell), Paragraph("<b>DUAL-TRIGGER CONFERMATO!</b>", style_table_cell_bold), Paragraph("<b>Scatta l'allarme acustico!</b> Evento fisico rarissimo certificato.", style_table_cell_bold)],
        [Paragraph("5", style_table_cell_bold), Paragraph("Barometro cala di 3 hPa in 2 ore in modo continuo", style_table_cell), Paragraph("Normale perturbazione meteorologica esterna.", style_table_cell), Paragraph("Nessuna anomalia paranormale, sta per piovere fuori.", style_table_cell)],
        [Paragraph("6", style_table_cell_bold), Paragraph("Barometro salta di 0.8 hPa in 1 secondo e ritorna", style_table_cell), Paragraph("Onda d'urto barometrica o spiffero improvviso.", style_table_cell), Paragraph("Verifica se qualcuno ha aperto una porta nella stanza attigua.", style_table_cell)],
        [Paragraph("7", style_table_cell_bold), Paragraph("Audio Peak costante a 50 Hz con -40 dBFS", style_table_cell), Paragraph("Ronzio di rete elettrica non filtrato o telefono in carica.", style_table_cell), Paragraph("Stacca il caricabatterie e verifica che il filtro Notch sia attivo.", style_table_cell)],
        [Paragraph("8", style_table_cell_bold), Paragraph("Audio Peak a 1250 Hz nel silenzio della stanza", style_table_cell), Paragraph("Frequenza vocale o risonanza acustica chiusa.", style_table_cell), Paragraph("Ascolta con le cuffie: potrebbe esserci un suono debole nell'aria.", style_table_cell)],
        [Paragraph("9", style_table_cell_bold), Paragraph("EMF oscilla sinusoidalmente ogni 5 secondi", style_table_cell), Paragraph("Motore ciclico (frigorifero o pompa di calore).", style_table_cell), Paragraph("Individua l'elettrodomestico responsabile e annotalo nel log.", style_table_cell)],
        [Paragraph("10", style_table_cell_bold), Paragraph("EMF sale non appena avvicini la mano", style_table_cell), Paragraph("Interferenza da anelli d'oro/argento o smartwatch.", style_table_cell), Paragraph("Togli tutti i gioielli e l'orologio dal polso dell'operatore.", style_table_cell)],
        [Paragraph("11", style_table_cell_bold), Paragraph("Valore EMF sempre a 120 µT ovunque ti sposti", style_table_cell), Paragraph("Cover del telefono con piastra magnetica per auto.", style_table_cell), Paragraph("Rimuovi immediatamente la cover protettiva dallo smartphone!", style_table_cell)],
        [Paragraph("12", style_table_cell_bold), Paragraph("S-Meter nello sweep sale a S9+ con audio che gracchi", style_table_cell), Paragraph("Forte modulazione reattiva legata a campo magnetico.", style_table_cell), Paragraph("Premi PAUSA per bloccare la frequenza e fare verifiche.", style_table_cell)],
        [Paragraph("13", style_table_cell_bold), Paragraph("La scala radio scorre da sola verso sinistra", style_table_cell), Paragraph("È attivo il tasto [ REV ◀ ] (scansione inversa).", style_table_cell), Paragraph("Normale: tocca [ FWD ▶ ] se preferisci avanzare a destra.", style_table_cell)],
        [Paragraph("14", style_table_cell_bold), Paragraph("Pillola arancione UNCALIBRATED sempre accesa", style_table_cell), Paragraph("Baseline standard di fabbrica attiva (42.0 µT).", style_table_cell), Paragraph("Funziona perfettamente! Premi 🎛️ solo se vuoi tarare la stanza.", style_table_cell)],
        [Paragraph("15", style_table_cell_bold), Paragraph("Calibrazione si interrompe da sola al secondo 14", style_table_cell), Paragraph("Qualcuno ha toccato il telefono durante la procedura.", style_table_cell), Paragraph("Ripeti la calibrazione senza toccare il tavolo per 30 secondi.", style_table_cell)],
        [Paragraph("16", style_table_cell_bold), Paragraph("Lo spettrogramma FFT mostra tutte le barre alte", style_table_cell), Paragraph("Saturazione microfonica (vento o operatore che grida).", style_table_cell), Paragraph("Allontana il telefono da fonti di ventilazione diretta.", style_table_cell)],
        [Paragraph("17", style_table_cell_bold), Paragraph("L'oscilloscopio vettoriale disegna una linea spessa", style_table_cell), Paragraph("Presenza di micro-rumore elettrico ad alta frequenza.", style_table_cell), Paragraph("Verifica se ci sono lampade a risparmio energetico o router Wi-Fi.", style_table_cell)],
        [Paragraph("18", style_table_cell_bold), Paragraph("Z-Score a 3.4σ per 3 secondi consecutivi", style_table_cell), Paragraph("Quasi anomalia forense, ma appena sotto la soglia 3.5σ.", style_table_cell), Paragraph("L'app registra l'evento nel CSV ma non attiva l'allarme severo.", style_table_cell)],
        [Paragraph("19", style_table_cell_bold), Paragraph("Il file CSV aperto in Excel mostra tutte le celle attaccate", style_table_cell), Paragraph("Separatore di elenco di Windows impostato a punto anziché virgola.", style_table_cell), Paragraph("Usa la funzione 'Testo in Colonne' di Excel selezionando la virgola.", style_table_cell)],
        [Paragraph("20", style_table_cell_bold), Paragraph("Lo scudo forense mostra un hash diverso tra due sessioni", style_table_cell), Paragraph("Comportamento matematicamente perfetto e garantito.", style_table_cell), Paragraph("Ogni sessione è unica e irripetibile; l'hash la firma in modo esclusivo.", style_table_cell)],
    ]
    cs_t = Table(cases_data, colWidths=[20, 155, 160, printable_width - 335])
    cs_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('BACKGROUND', (0,4), (-1,4), c_green_light),
        ('TOPPADDING', (0,0), (-1,-1), 3.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(cs_t)

    # =========================================================================
    # CAPITOLO 12: DOMANDE FREQUENTI (FAQ)
    # =========================================================================
    story.extend(chapter_header("Domande Frequenti (FAQ) e Risoluzione dei Dubbi", 12))
    
    faqs = [
        ("D: Perché il valore EMF non è mai 0.0 µT ma segna sempre tra 35 e 55 µT?",
         "R: È normalissimo! Il pianeta Terra su cui viviamo è un gigantesco magnete naturale che genera continuamente un campo protettivo (quello che fa orientare le bussole verso il Polo Nord). In Italia ed Europa, il campo naturale terrestre oscilla proprio tra 35 e 55 microTesla. Se segnasse zero, significherebbe che il tuo sensore è rotto o che ti trovi nello spazio siderale!"),
         
        ("D: Ho toccato lo smartphone forte, ma l'allarme sonoro non è partito. Perché?",
         "R: Perché AetherScan-Pro è severissima! Ha registrato l'urto sul telaio (scrivendo 'URTO MECCANICO' in rosso), ma poiché non c'era alcuna anomalia magnetica in quel momento, il programma ha capito che si trattava solo di un contatto fisico ordinario e non ha fatto suonare l'allarme. L'allarme suona SOLO se nello stesso istante c'è anche un'anomalia Z ≥ 3.5σ."),
         
        ("D: Cosa devo fare se la calibrazione segna valori altissimi?",
         "R: Significa che il telefono è troppo vicino a una massa ferrosa (tubature dell'acqua nei muri, una trave d'acciaio nel pavimento, una cassa altoparlante o una presa). Sposta il telefono di un metro in una posizione più neutra e ripeti la calibrazione di 30 secondi."),
         
        ("D: Posso usare l'applicazione senza calibrare appena la apro?",
         "R: Certamente! Nella versione v27-beta2 abbiamo preimpostato una baseline standard terrestre di fabbrica (42 µT). Puoi aprire l'app e usarla all'istante senza dover aspettare nemmeno un secondo. La calibrazione manuale serve solo se desideri la precisione massima calibrata sulla stanza specifica."),
         
        ("D: A cosa servono i due tasti REV e FWD nella radio?",
         "R: Servono a scegliere la direzione di scorrimento delle frequenze radio. [ REV ◀ ] scorre all'indietro verso frequenze minori; [ FWD ▶ ] scorre in avanti verso frequenze maggiori. Entrambi i tasti sono sempre visibili e illuminati con colori diversi (ambra e ciano) per non confonderti mai."),
         
        ("D: Dove vengono salvati i file sul mio telefono?",
         "R: I file CSV e JSON vengono salvati nella cartella pubblica Documenti o Download del tuo dispositivo, all'interno della sottocartella dedicata <code>AetherScan-Pro/logs</code>. Puoi collegare il telefono al PC con il cavo USB per scaricarli subito.")
    ]

    for q, a in faqs:
        story.append(Paragraph(f"<b>{q}</b>", style_h3))
        story.append(Paragraph(a, style_body))
        story.append(Spacer(1, 4))

    # =========================================================================
    # CAPITOLO 13: GLOSSARIO SCIENTIFICO DALLA A ALLA Z
    # =========================================================================
    story.extend(chapter_header("Glossario Scientifico Illustrato dalla A alla Z", 13))
    story.append(Paragraph("Tutti i termini tecnici del progetto spiegati con parole chiarissime per chiunque:", style_body))
    story.append(Spacer(1, 6))

    glossary_data = [
        [Paragraph("<b>TERMINE</b>", style_table_header), Paragraph("<b>DEFINIZIONE SEMPLICE</b>", style_table_header), Paragraph("<b>ANALOGIA PRATICA</b>", style_table_header)],
        [
            Paragraph("<b>Accelerometro</b>", style_table_cell_bold),
            Paragraph("Sensore che misura le accelerazioni e gli urti sul telefono.", style_table_cell),
            Paragraph("Come il sensore dell'airbag dell'auto che capisce quando c'è stato un impatto.", style_table_cell)
        ],
        [
            Paragraph("<b>Barometro</b>", style_table_cell_bold),
            Paragraph("Sensore che misura la pressione esercitata dall'aria circostante.", style_table_cell),
            Paragraph("Come la sensazione che provi alle orecchie quando sali rapidamente in funivia.", style_table_cell)
        ],
        [
            Paragraph("<b>Baseline</b>", style_table_cell_bold),
            Paragraph("La linea di base, ovvero il valore medio della quiete della stanza.", style_table_cell),
            Paragraph("Come il livello del mare calmo prima che arrivi un'onda.", style_table_cell)
        ],
        [
            Paragraph("<b>dBFS (Decibel Full Scale)</b>", style_table_cell_bold),
            Paragraph("Unità di misura del volume sonoro digitale con scala negativa fino a 0.", style_table_cell),
            Paragraph("Come un bicchiere d'acqua: 0 dBFS è l'orlo pieno, -80 dBFS è quasi vuoto.", style_table_cell)
        ],
        [
            Paragraph("<b>dBm (Decibel-milliwatt)</b>", style_table_cell_bold),
            Paragraph("Misura della potenza elettromagnetica o radio ricevuta.", style_table_cell),
            Paragraph("Come le 'tacche' del segnale cellulare sul display del tuo telefono.", style_table_cell)
        ],
        [
            Paragraph("<b>Dual-Trigger</b>", style_table_cell_bold),
            Paragraph("Logica di doppia coincidenza simultanea obbligatoria.", style_table_cell),
            Paragraph("Come le due chiavi della cassaforte di una banca: devono girare insieme!", style_table_cell)
        ],
        [
            Paragraph("<b>EMF (Electro-Magnetic Field)</b>", style_table_cell_bold),
            Paragraph("Campo Elettromagnetico generato da cariche elettriche o masse magnetiche.", style_table_cell),
            Paragraph("Come la forza invisibile che fa attaccare due calamite senza toccarsi.", style_table_cell)
        ],
        [
            Paragraph("<b>FFT (Fast Fourier Transform)</b>", style_table_cell_bold),
            Paragraph("Formula matematica che scompone un suono complesso nelle sue singole note musicali.", style_table_cell),
            Paragraph("Come un prisma di vetro che scompone un raggio di luce bianca nei colori dell'arcobaleno.", style_table_cell)
        ],
        [
            Paragraph("<b>Filtro Notch 50 Hz</b>", style_table_cell_bold),
            Paragraph("Filtro elettronico/matematico a fessura che elimina solo la frequenza a 50 Hz.", style_table_cell),
            Paragraph("Come un setaccio con maglie speciali che fa passare la farina ma blocca i sassolini.", style_table_cell)
        ],
        [
            Paragraph("<b>Hash SHA-256</b>", style_table_cell_bold),
            Paragraph("Codice crittografico univoco a 64 caratteri che certifica l'integrità del registro.", style_table_cell),
            Paragraph("Come l'impronta digitale sul passaporto: non esistono due persone con la stessa impronta.", style_table_cell)
        ],
        [
            Paragraph("<b>Hectopascal (hPa)</b>", style_table_cell_bold),
            Paragraph("Unità di misura della pressione atmosferica (1 hPa = 100 Pascal).", style_table_cell),
            Paragraph("1013.25 hPa è il peso standard dell'atmosfera terrestre sulla testa.", style_table_cell)
        ],
        [
            Paragraph("<b>MicroTesla (µT)</b>", style_table_cell_bold),
            Paragraph("Unità di misura dell'induzione magnetica (un milionesimo di Tesla).", style_table_cell),
            Paragraph("Il campo magnetico della Terra vale normalmente tra 35 e 55 µT.", style_table_cell)
        ],
        [
            Paragraph("<b>RFC 4180</b>", style_table_cell_bold),
            Paragraph("Lo standard internazionale ufficiale per i file di testo CSV tabulari.", style_table_cell),
            Paragraph("La regola universale che permette a qualsiasi computer del mondo di aprire la tabella senza errori.", style_table_cell)
        ],
        [
            Paragraph("<b>S-Meter</b>", style_table_cell_bold),
            Paragraph("Strumento storico dei radioamatori per misurare la potenza del segnale (da S1 a S9).", style_table_cell),
            Paragraph("Come il contachilometri della macchina che ti dice quanto stai andando forte.", style_table_cell)
        ],
        [
            Paragraph("<b>Welford (Algoritmo)</b>", style_table_cell_bold),
            Paragraph("Metodo ricorsivo per calcolare media e varianza senza accumulare dati in memoria.", style_table_cell),
            Paragraph("Un calcolo ultrarapido che protegge la batteria del telefono dal surriscaldamento.", style_table_cell)
        ],
        [
            Paragraph("<b>Z-Score (Punteggio Z)</b>", style_table_cell_bold),
            Paragraph("Indice statistico che misura quante deviazioni standard dista un valore dalla normalità.", style_table_cell),
            Paragraph("Z ≥ 3.5σ significa che la probabilità che sia un caso è minore di 1 su 2000!", style_table_cell)
        ],
    ]
    gl_t = Table(glossary_data, colWidths=[115, 175, printable_width - 290])
    gl_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(gl_t)

    # =========================================================================
    # CAPITOLO 14: SCHEDA TECNICA DI RILASCIO & CHECKSUM
    # =========================================================================
    story.extend(chapter_header("Scheda Tecnica di Rilascio & Checksum Ufficiali", 14))
    
    story.append(Paragraph("14.1 Pacchetti Compilati e Sicurezza Crittografica", style_h2))
    story.append(Paragraph(
        "Tutti i file binari generati e distribuiti sono firmati crittograficamente con algoritmo SHA-256. "
        "Puoi verificare tu stesso che il file scaricato sia autentico e non contenga virus o alterazioni confrontando il codice hash qui riportato:",
        style_body
    ))
    story.append(Spacer(1, 6))

    release_data = [
        [Paragraph("<b>PACCHETTO DI RILASCIO</b>", style_table_header), Paragraph("<b>PERCORSO LOCALE UFFICIALE</b>", style_table_header), Paragraph("<b>IMPRONTA CRITTOGRAFICA SHA-256</b>", style_table_header)],
        [
            Paragraph("<b>Android APK Release:</b><br/>AetherScan-Pro-v27-beta2-Metrology.apk", style_table_cell_bold),
            Paragraph("<code>D:\\AetherScan-Pro\\DISTRIBUZIONE-FINALE\\</code>", style_code),
            Paragraph("<code>53311304BF4984F22E561827C772C40C28CE81FCEFEDD8DC5CD0D9F88C35FF0D</code>", style_code)
        ],
        [
            Paragraph("<b>Apple iOS IPA Unsigned:</b><br/>AetherScan-Pro-v27-beta2-Metrology-unsigned.ipa", style_table_cell_bold),
            Paragraph("<code>D:\\AetherScan-Pro\\DISTRIBUZIONE-FINALE\\</code>", style_code),
            Paragraph("<code>5C309F2B35104E66080713B29EC9445EF9CC574378F656C6F44691969A42E050</code>", style_code)
        ],
        [
            Paragraph("<b>Archivio Storico Intatto:</b><br/>(v26-beta1 Backup)", style_table_cell_bold),
            Paragraph("<code>D:\\AetherScan-Pro\\android\\android\\AetherScan-Pro-apk-IPA\\</code>", style_code),
            Paragraph("<b>100% Blindato, Protetto e Non Modificato</b>", style_table_cell)
        ],
    ]
    rel_t = Table(release_data, colWidths=[150, 140, printable_width - 290])
    rel_t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_cyan_dark),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_subtle]),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(rel_t)
    story.append(Spacer(1, 15))

    colophon_text = """
    <b>COLOPHON E NOTE DI CHIUSURA:</b><br/>
    Documento compilato e certificato in conformità agli standard Open Forensics & Industrial Metrology.<br/>
    Progetto: <b>AetherScan-Pro v2.0 (v27-beta2)</b> • Motore di Calcolo: Flutter 3.x / Dart 3.x • Piattaforme: Android & iOS.<br/>
    Nessun algoritmo di simulazione vocale o PRNG è stato impiegato nello sviluppo del software.<br/>
    Tutti i diritti riservati all'autore del progetto. Fanne buon uso nella ricerca della verità sul campo!
    """
    story.append(callout("CHIUSURA ATTI METROLOGICI", colophon_text, kind="info"))

    print("Building comprehensive PDF manual...")
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Definitive PDF successfully generated at: {output_pdf}")

if __name__ == '__main__':
    build_pdf_manual()

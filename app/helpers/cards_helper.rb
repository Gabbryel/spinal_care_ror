module CardsHelper
  def cards
    cards = [
      {
        icon: '<i class="fas fa-hand-holding-usd"></i>',
        title: 'Tarife',
        content: 'Avem prețuri competitive și contract cu Casa de Asigurări',
        link_text: 'Mai multe informații...',
        link: '/servicii-medicale',
        data_controller: '-',
        data_target: '-',
        data_action: '-',
        type: 'link_to'
      },
      {
        icon: '<i class="fa-solid fa-chart-line"></i>',
        title: 'Strategie',
        content: 'Urmărim cu atenție inovația din domeniu și achiziționăm aparatură performantă',
        link_text: 'Mai multe informații...',
        link: '#',
        data_controller: 'contact',
        type: 'link_to'
      },
      {
        icon: '<i class="fas fa-university"></i>',
        title: 'Pregătire',
        content: 'Credem în principiul studiului pe tot parcursul carierei.',
        link_text: 'Mai multe informații...',
        link: '#',
        data_controller: 'contact',
        type: 'link_to'
      },
      {
        icon: '<i class="fa-solid fa-phone"></i>',
        title: 'Contact',
        content: 'Vă stăm la dispoziție pentru programări, sfaturi și susținere',
        link_text: 'Contactează-ne',
        link: '#',
        data_controller: 'contact',
        data_target: 'contact',
        data_action: 'click->contact#contact',
        type: 'button_tag'
      },
    ]
  end
end
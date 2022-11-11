module CardsHelper
  def cards
    cards = [
      {
        icon: '<i class="fas fa-hand-holding-usd"></i>',
        title: 'Tarife',
        content: 'Avem prețuri competitive și contract cu Casa de Asigurări',
        link: '/servicii-medicale',
      },
      {
        icon: '<i class="fas fa-hand-holding-usd"></i>',
        title: 'Strategie',
        content: 'Urmărim cu atenție inovația din domeniu și achiziționăm aparatură performantă',
        link: '#',
      },
      {
        icon: '<i class="fas fa-university"></i>',
        title: 'Pregătire',
        content: 'Credem în principiul studiului pe tot parcursul carierei.',
        link: '#',
      },
      {
        icon: '<i class="fas fa-hand-holding-usd"></i>',
        title: 'Contact',
        content: 'Vă stăm la dispoziție pentru programări, sfaturi și susținere',
        link: '#',
      },
    ]
  end
end
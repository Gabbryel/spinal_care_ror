module ReviewsCardsHelper
  def reviews_cards
    [{
      author: 'Nicolae Ciucă',
      rating: 5,
      content: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris molestie, lectus lacinia ornare convallis, purus urna tristique orci, nec dapibus metus libero eget dolor.',
      created_at: '28.07.2021'
    },
    {
      author: 'Gigi Duru',
      rating: 5,
      content: 'Proin laoreet in nisl quis viverra. Nullam placerat ex quis sollicitudin facilisis. Cras iaculis augue pretium, vestibulum libero ut, ultrices nibh.',
      created_at: '28.07.2021',
    },
    {
      author: 'Herodot',
      rating: 5,
      content: 'Proin laoreet in nisl quis viverra. Nullam placerat ex quis sollicitudin facilisis. Cras iaculis augue pretium, vestibulum libero ut, ultrices nibh.',
      created_at: '31.07.2021',
    }
  ]
  end
end
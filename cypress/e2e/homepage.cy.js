describe('Static site', () => {
  it('loads homepage', () => {
    cy.visit('http://steph-vgo-website.s3-website-us-east-1.amazonaws.com')
    cy.contains('visitors')
  })
})

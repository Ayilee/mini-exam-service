import request from 'supertest'
import app from '../app.js'

describe('GET /api/hello', () => {
  it('returns { message: "hello" }', async () => {
    const res = await request(app).get('/api/hello')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ message: 'hello' })
  })
})
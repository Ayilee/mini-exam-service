//
import express from 'express'

const app = express()

app.get('/api/hello', (_req, res) => {
  res.json({ message: 'hello' })
})

app.get('/health', (_req, res) => {
  res.json({ status: 'UP' })
})

export default app

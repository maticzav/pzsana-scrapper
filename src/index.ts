import puppeteer, { Browser, ElementHandle } from 'puppeteer'
import * as fs from 'fs'
import * as path from 'path'
import ora from 'ora'
import mkdirp = require('mkdirp')

/**
 *
 * Config
 *
 */

const pzsana = `http://www.pzsana.net/pzsana/alltime1.php`
const gender: PZSAnaOptions['gender'] = 'MM'
const course: PZSAnaOptions['course'] = '50D'
const samples = 1000
const extractDir = `dist`
const extractFile = `data.json`

/**
 *
 * Main function
 *
 */

async function main() {
  const browser = await puppeteer.launch()

  const flyLongCourse = await getResultsFor(browser, {
    gender: gender,
    pool: 'L',
    course: course,
    numberOfResults: samples,
  })

  const flyShortCourse = await getResultsFor(browser, {
    gender: gender,
    pool: 'Z',
    course: course,
    numberOfResults: samples,
  })

  const results = combineResults('swimmer_name', [
    {
      name: 'longCoursePoolTime',
      resolve: (e: any) => e.time,
      data: flyLongCourse,
    },
    {
      name: 'shortCoursePoolTime',
      resolve: (e: any) => e.time,
      data: flyShortCourse,
    },
  ])

  return extractData(extractDir, extractFile, results)
}

ora.promise(main(), {
  text: 'Loading results...',
})

/**
 *
 * Helper functions
 *
 */

async function extractData(dir: string, file: string, data: any[]) {
  const outputDir = path.resolve(process.cwd(), dir)
  const outputFile = path.resolve(process.cwd(), dir, file)

  const content = JSON.stringify(
    {
      size: data.length,
      data,
    },
    null,
    2,
  )

  mkdirp(outputDir, err => {
    if (err) throw err

    fs.writeFileSync(outputFile, content)
  })
}

function combineResults(
  head: string,
  results: {
    name: string
    resolve: <T>(result: T) => any
    data: any[]
  }[],
): any {
  /**
   *
   * Combines the data from all resources into one.
   * Marks origin by wrapping it under name.
   *
   */
  const bigdata = results.reduce<
    { data: any; name: string; resolve: <T>(result: T) => any }[]
  >(
    (acc, result) => [
      ...acc,
      ...result.data.map(data => ({
        data,
        name: result.name,
        resolve: result.resolve,
      })),
    ],
    [],
  )

  const combined = bigdata.reduce<any[]>((acc, unit) => {
    const identifier = unit.data[head]

    // Already merged
    if (acc.some(comb => comb[head] === identifier)) {
      return acc
    }

    const combinedProps = bigdata
      .filter(data => identifier === data.data[head])
      .reduce(
        (acc, data) => ({
          ...acc,
          [data.name]: unit.resolve(data.data),
        }),
        {},
      )

    return acc.concat({
      [head]: unit.data[head],
      ...combinedProps,
    })
  }, [])

  const completeCombinations = combined.filter(combination =>
    results.every(result => combination.hasOwnProperty(result.name)),
  )

  return completeCombinations
}

interface PZSAnaResult {
  swimmer_id: string
  swimmer_name: string
  swimmer_age: number
  time: string
}

async function getResultsFor(
  browser: Browser,
  options: PZSAnaOptions,
): Promise<PZSAnaResult[]> {
  const page = await browser.newPage()

  const pageURL = parseURL(pzsana, options)
  await page.goto(pageURL)

  /**
   *
   * Struktura tabele:
   * mesto ime letnik(starost) klub čas točke datum kraj
   *
   */
  const tables = await page.$$('tbody')
  const rows = await Promise.all(
    tables.map(async table => {
      const [, ...rows] = await table!.$$('tr')
      return rows
    }),
  ).then(tables =>
    tables.reduce((acc, tableRows) => [...acc, ...tableRows], []),
  )

  const results = await Promise.all(
    rows.map(
      parseRow([
        ignoreColumn,
        parseColumnName,
        parseColumnAge,
        ignoreColumn,
        parseColumnTime,
        ignoreColumn,
        ignoreColumn,
        ignoreColumn,
      ]),
    ),
  )

  const nonNullResults = results.filter(notNull)

  return nonNullResults

  /**
   *
   * Helper functions
   *
   */
  function parseRow(
    funcs: ((element: ElementHandle<Element>) => Promise<any>)[],
  ) {
    return async function(
      row: ElementHandle<Element>,
    ): Promise<PZSAnaResult | null> {
      const columns = await row.$$('td')

      try {
        const resolvedColumns = await Promise.all(
          columns.map((column, i) => funcs[i](column)),
        )

        return resolvedColumns.reduce<PZSAnaResult>(
          (acc, column) => {
            if (column === null) {
              return acc
            } else {
              return {
                ...acc,
                ...column,
              }
            }
          },
          {} as any,
        )
      } catch (err) {
        return null
      }
    }
  }

  // Parsers

  async function ignoreColumn(el: ElementHandle<Element>) {
    return null
  }

  async function parseColumnName(element: ElementHandle<Element>) {
    return element.$eval('p a', node => {
      return {
        swimmer_id: node.getAttribute('href'),
        swimmer_name: node.innerHTML,
      }
    })
  }

  async function parseColumnAge(element: ElementHandle<Element>) {
    return element.$eval('p small', node => {
      return {
        swimmer_age: node.innerHTML,
      }
    })
  }

  async function parseColumnTime(element: ElementHandle<Element>) {
    return element.$eval('p', node => {
      const [, minutes, seconds, deciseconds] = /(\d):(\d*),(\d*)/.exec(
        node.innerHTML,
      )!

      console.log({ minutes, seconds, deciseconds })

      const time =
        60 * parseInt(minutes) +
        parseInt(seconds) +
        0.01 * parseInt(deciseconds)

      return { time }
    })
  }

  function notNull<T>(el: T | null): el is T {
    return el !== null
  }
}

interface PZSAnaOptions {
  numberOfResults: number
  gender:
    | 'MA'
    | 'MC'
    | 'MM'
    | 'MK'
    | 'MD'
    | 'MM_D'
    | 'ZA'
    | 'ZC'
    | 'ZM'
    | 'ZK'
    | 'ZD'
    | 'ZM_D'
  course:
    | '50K'
    | '100K'
    | '200K'
    | '50D'
    | '100D'
    | '200D'
    | '50P'
    | '100P'
    | '200P'
    | '50H'
    | '100H'
    | '200H'
    | '50M'
    | '100M'
    | '200M'
  pool: 'Z' | 'L'
}

function parseURL(base: string, options: PZSAnaOptions): string {
  const query = parseQuery(options)

  return `${base}?${query}`
}

function parseQuery(options: PZSAnaOptions): string {
  const url = new URLSearchParams(
    'klub=&samo_en=ON&fina=2019&od=1990-1-1&do=2018-11-7&zaprto=ON',
  )

  url.set('stevilo', options.numberOfResults.toString())
  url.set('spol', options.gender)
  url.set('disc', options.course)
  url.set('bazen', options.pool)

  return url.toString()
}
